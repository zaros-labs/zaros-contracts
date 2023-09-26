// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { ILogAutomation, Log as AutomationLog } from "@zaros/external/interfaces/chainlink/ILogAutomation.sol";
import {
    IStreamsLookupCompatible, BasicReport
} from "@zaros/external/interfaces/chainlink/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "@zaros/external/interfaces/chainlink/IVerifierProxy.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { ISettlementModule } from "../interfaces/ISettlementModule.sol";
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

abstract contract SettlementModule is ISettlementModule, ILogAutomation, IStreamsLookupCompatible {
    using Order for Order.Data;
    using PerpsAccount for PerpsAccount.Data;
    using PerpsMarket for PerpsMarket.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using SafeCast for int256;

    modifier onlyForwarder() {
        address forwarder = PerpsConfiguration.load().chainlinkForwarder;
        if (msg.sender != forwarder) {
            revert Zaros_SettlementModule_OnlyForwarder(msg.sender, forwarder);
        }
        _;
    }

    function checkLog(
        AutomationLog calldata log,
        bytes calldata checkData
    )
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        (uint256 accountId, uint128 marketId) = (uint256(log.topics[1]), uint256(log.topics[2]).toUint128());
        bytes32 streamId = PerpsMarket.load(marketId).streamId;
        (Order.Data memory order) = abi.decode(log.data, (Order.Data));

        // TODO: we should probably have orderType as an indexed parameter?
        if (order.payload.orderType != Order.OrderType.MARKET) {
            return (false, bytes(""));
        }

        // TODO: add proper order.validate() check
        string[] memory feeds = new string[](1);
        feeds[0] = string(abi.encodePacked(streamId));
        bytes memory extraData = abi.encode(accountId, marketId, order.id);

        revert StreamsLookup(
            Constants.DATA_STREAMS_FEED_LABEL,
            feeds,
            Constants.DATA_STREAMS_QUERY_LABEL,
            order.settlementTimestamp,
            extraData
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

    function performUpkeep(bytes calldata performData) external onlyForwarder {
        IVerifierProxy chainlinkVerifier = IVerifierProxy(PerpsConfiguration.load().chainlinkVerifier);
        (bytes[] memory signedReports, bytes memory extraData) = abi.decode(performData, (bytes[], bytes));

        bytes memory unverifiedReportData = signedReports[0];
        BasicReport memory unverifiedReport = _decodeReport(unverifiedReportData);
        bytes memory verifiedReportData =
            chainlinkVerifier.verify{ value: unverifiedReport.nativeFee }(unverifiedReportData);
        BasicReport memory verifiedReport = _decodeReport(verifiedReportData);

        (uint256 accountId, uint128 marketId, uint8 orderId) = abi.decode(extraData, (uint256, uint128, uint8));
        Order.Data storage order = PerpsMarket.load(marketId).orders[accountId][orderId];

        _settleOrder(order, verifiedReport);
    }

    function _decodeReport(bytes memory report) internal pure returns (BasicReport memory) {
        return abi.decode(report, (BasicReport));
    }

    // TODO: many validations pending
    function _settleOrder(Order.Data storage order, BasicReport memory report) internal {
        SettlementRuntime memory runtime;
        runtime.marketId = order.payload.marketId;
        runtime.accountId = order.payload.accountId;

        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(runtime.marketId);
        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(runtime.accountId);
        Position.Data storage oldPosition = perpsMarket.positions[runtime.accountId];
        address usdToken = PerpsConfiguration.load().usdToken;

        // TODO: apply price impact
        runtime.fillPrice = sd59x18(report.price).intoUD60x18();
        SD59x18 fundingFeePerUnit = perpsMarket.calculateNextFundingFeePerUnit(runtime.fillPrice);
        SD59x18 accruedFunding = oldPosition.getAccruedFunding(fundingFeePerUnit);
        SD59x18 currentUnrealizedPnl = oldPosition.getUnrealizedPnl(runtime.fillPrice, accruedFunding);
        // this will change
        runtime.pnl = currentUnrealizedPnl;
        runtime.unrealizedPnlToStore = sd59x18(0);

        // for now we'll realize the total uPnL, we should realize it proportionally in the future
        if (runtime.pnl.lt(SD_ZERO)) {
            perpsAccount.deductAccountMargin(runtime.pnl.intoUD60x18());
        } else if (runtime.pnl.gt(SD_ZERO)) {
            perpsAccount.increaseMarginCollateral(usdToken, runtime.pnl.intoUD60x18());
        }
        UD60x18 initialMargin =
            ud60x18(oldPosition.initialMargin).add(sd59x18(order.payload.initialMarginDelta).intoUD60x18());

        // TODO: validate initial margin and size
        runtime.newPosition = Position.Data({
            size: sd59x18(oldPosition.size).add(sd59x18(order.payload.sizeDelta)).intoInt256(),
            initialMargin: initialMargin.intoUint128(),
            unrealizedPnlStored: runtime.unrealizedPnlToStore.intoInt256().toInt128(),
            lastInteractionPrice: runtime.fillPrice.intoUint128(),
            lastInteractionFundingFeePerUnit: fundingFeePerUnit.intoInt256().toInt128()
        });

        order.reset();
        perpsAccount.updateActiveOrders(runtime.marketId, order.id, false);
        oldPosition.update(runtime.newPosition);

        emit LogSettleOrder(msg.sender, runtime.accountId, runtime.marketId, order, runtime.newPosition);
    }
}
