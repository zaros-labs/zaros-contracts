// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { ILogAutomation, Log as AutomationLog } from "@zaros/external/interfaces/chainlink/ILogAutomation.sol";
import {
    IStreamsLookupCompatible, BasicReport
} from "@zaros/external/interfaces/chainlink/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "@zaros/external/interfaces/chainlink/IVerifierProxy.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { ISettlementEngineModule } from "../interfaces/ISettlementEngineModule.sol";
import { Order } from "../storage/Order.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { PerpsConfiguration } from "../storage/PerpsConfiguration.sol";
import { PerpsMarket } from "../storage/PerpsMarket.sol";
import { Position } from "../storage/Position.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

abstract contract SettlementEngineModule is ISettlementEngineModule, ILogAutomation, IStreamsLookupCompatible {
    using Order for Order.Data;
    using PerpsAccount for PerpsAccount.Data;
    using PerpsMarket for PerpsMarket.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using SafeCast for int256;

    function checkLog(
        AutomationLog calldata log,
        bytes calldata checkData
    )
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // TODO: update to use order.settlementTimestamp
        uint256 settlementTimestamp = log.timestamp;
        (uint256 accountId, uint128 marketId) = (uint256(log.topics[1]), uint256(log.topics[2]).toUint128());
        (Order.Data memory order) = abi.decode(log.data, (uint8, Order.Data));
        // TODO: add proper order.validate() check
        string[] memory feeds = new string[](1);
        // ETH-USD feed id
        feeds[0] = "0x00023496426b520583ae20a66d80484e0fc18544866a5b0bfee15ec771963274";
        bytes memory extraData = abi.encode(orderId, order);

        revert StreamsLookup(
            Constants.DATA_STREAMS_FEED_LABEL, feeds, Constants.DATA_STREAMS_QUERY_LABEL, settlementTimestamp, extraData
        );
    }

    function checkCallback(
        bytes[] memory values,
        bytes memory extraData
    )
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        return (true, abi.encode(values, extraData));
    }

    function performUpkeep(bytes calldata performData) external {
        IVerifierProxy chainlinkVerifier = IVerifierProxy(PerpsConfiguration.load().chainlinkVerifier);
        (bytes[] memory signedReports, bytes memory extraData) = abi.decode(performData, (bytes[], bytes));
        // implement
        uint256 chainlinkFee;
        bytes memory unverifiedReportData = signedReports[0];
        BasicReport memory unverifiedReport = _getReport(unverifiedReportData);
        bytes memory verifiedReportData =
            chainlinkVerifier.verify{ value: unverifiedReport.nativeFee }(unverifiedReportData);
        BasicReport memory verifiedReport = _getReport(verifiedReportData);
        (uint8 orderId, Order.Data memory order) = abi.decode(extraData, (uint8, Order.Data));

        _settleOrder(order.payload.marketId, order.payload.accountId, orderId, verifiedReport);
    }

    function _getReport(bytes memory report) internal pure returns (BasicReport memory) {
        return abi.decode(report, (BasicReport));
    }

    // TODO: many validations pending
    function _settleOrder(Order.Data memory order, BasicReport memory report) internal {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);
        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);
        Order.Data storage order = perpsMarket.orders[accountId][orderId];
        Position.Data storage oldPosition = perpsMarket.positions[accountId];
        address usdToken = PerpsConfiguration.load().usdToken;

        // TODO: apply price impact
        UD60x18 price = sd59x18(report.price).intoUD60x18();
        SD59x18 fundingFeePerUnit = perpsMarket.calculateNextFundingFeePerUnit(price);
        SD59x18 accruedFunding = oldPosition.getAccruedFunding(fundingFeePerUnit);
        SD59x18 currentUnrealizedPnl = oldPosition.getUnrealizedPnl(price, accruedFunding);
        // this will change
        SD59x18 pnlToRealize = currentUnrealizedPnl;
        int128 unrealizedPnlToStore = int128(0);

        // for now we'll realize the total uPnL, we should realize it proportionally in the future
        if (pnlToRealize.lt(SD_ZERO)) {
            perpsAccount.deductAccountMargin(pnlToRealize.intoUD60x18());
        } else if (pnlToRealize.gt(SD_ZERO)) {
            perpsAccount.increaseMarginCollateral(usdToken, pnlToRealize.intoUD60x18());
        }

        SD59x18 newPositionSize = sd59x18(oldPosition.size).add(sd59x18(order.payload.sizeDelta));
        // TODO: validate initial margin
        UD60x18 initialMargin =
            ud60x18(oldPosition.initialMargin).add(sd59x18(order.payload.initialMarginDelta).intoUD60x18());
        Position.Data memory newPosition = Position.Data({
            size: newPositionSize.intoInt256(),
            initialMargin: initialMargin.intoUint128(),
            unrealizedPnlStored: unrealizedPnlToStore,
            lastInteractionPrice: price.intoUint128(),
            lastInteractionFundingFeePerUnit: fundingFeePerUnit.intoInt256().toInt128()
        });

        order.reset();
        perpsAccount.updateActiveOrders(marketId, orderId, false);
        oldPosition.update(newPosition);

        // emit LogSettleOrder();
    }
}
