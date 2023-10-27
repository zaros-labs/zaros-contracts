// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { ILogAutomation, Log as AutomationLog } from "@zaros/external/interfaces/chainlink/ILogAutomation.sol";
import {
    IStreamsLookupCompatible,
    BasicReport,
    Quote
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
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

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
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        (uint256 accountId, uint128 marketId) = (uint256(log.topics[2]), uint256(log.topics[3]).toUint128());
        // bytes32 streamId = PerpsMarket.load(marketId).streamId;
        (Order.Data memory order) = abi.decode(log.data, (Order.Data));

        // TODO: we should probably have orderType as an indexed parameter?
        if (order.payload.orderType != Order.OrderType.MARKET) {
            return (false, bytes(""));
        }

        // TODO: add proper order.validate() check
        string[] memory feeds = new string[](1);
        if (marketId == 1) {
            feeds[0] = Constants.DATA_STREAMS_ETH_USD_STREAM_ID;
        } else if (marketId == 2) {
            feeds[0] = Constants.DATA_STREAMS_LINK_USD_STREAM_ID;
        } else {
            revert();
        }

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
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        return (true, abi.encode(values, extraData));
    }

    function performUpkeep(bytes calldata performData) external override onlyForwarder {
        IVerifierProxy chainlinkVerifier = IVerifierProxy(PerpsConfiguration.load().chainlinkVerifier);
        (bytes[] memory signedReports, bytes memory extraData) = abi.decode(performData, (bytes[], bytes));

        bytes memory signedReport = signedReports[0];
        bytes memory bundledReport = _bundleReport(signedReport);
        BasicReport memory unverifiedReport = _getReportData(bundledReport);

        bytes memory verifiedReportData = chainlinkVerifier.verify{ value: unverifiedReport.nativeFee }(bundledReport);
        BasicReport memory verifiedReport = abi.decode(verifiedReportData, (BasicReport));

        (uint256 accountId, uint128 marketId, uint8 orderId) = abi.decode(extraData, (uint256, uint128, uint8));
        Order.Data storage order = PerpsMarket.load(marketId).orders[accountId][orderId];

        _settleOrder(order, verifiedReport);
    }

    function settleOrder(uint256 accountId, uint128 marketId, uint8 orderId, uint256 price) external {
        Order.Data storage order = PerpsMarket.load(marketId).orders[accountId][orderId];

        BasicReport memory report;
        report.benchmark = int192(int256(price));

        _settleOrder(order, report);
    }

    function _bundleReport(bytes memory report) internal pure returns (bytes memory) {
        Quote memory quote;
        quote.quoteAddress = Constants.DATA_STREAMS_FEE_ADDRESS;
        (
            bytes32[3] memory reportContext,
            bytes memory reportData,
            bytes32[] memory rs,
            bytes32[] memory ss,
            bytes32 raw
        ) = abi.decode(report, (bytes32[3], bytes, bytes32[], bytes32[], bytes32));
        bytes memory bundledReport = abi.encode(reportContext, reportData, rs, ss, raw, abi.encode(quote));
        return bundledReport;
    }

    /**
     * @dev This function extracts the main report data from a signed report.
     *      The process involves the below steps:
     *      (1) It decodes the input signed report into its key attributes,
     *          with a focus on "reportData" because that's where the essential feed data sits.
     *      (2) It then re-decodes the "reportData" from its raw bytes format into a more
     *          usable "BasicReport" struct format.
     *      It's to note that, the decoded report data will include essential attributes of
     *      a report such as feed ID, timestamps, and fees, and the feed value agreed upon in OCR round.
     *      NOTE: these reports should always be passed into the verifier contract
     * @param signedReport A signed report instance in bytes format.
     * @return report The decoded report data in the form of a BasicReport struct.
     */
    function _getReportData(bytes memory signedReport) internal pure returns (BasicReport memory) {
        (, bytes memory reportData,,,) = abi.decode(signedReport, (bytes32[3], bytes, bytes32[], bytes32[], bytes32));

        BasicReport memory report = abi.decode(reportData, (BasicReport));
        return report;
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
        runtime.fillPrice = sd59x18(report.benchmark).intoUD60x18();
        SD59x18 fundingFeePerUnit = perpsMarket.calculateNextFundingFeePerUnit(runtime.fillPrice);
        SD59x18 accruedFunding = oldPosition.getAccruedFunding(fundingFeePerUnit);
        SD59x18 currentUnrealizedPnl = oldPosition.getUnrealizedPnl(runtime.fillPrice, accruedFunding);
        // this will change
        runtime.pnl = currentUnrealizedPnl;
        runtime.unrealizedPnlToStore = sd59x18(0);

        // for now we'll realize the total uPnL, we should realize it proportionally in the future
        // if (runtime.pnl.lt(SD_ZERO)) {
        //     perpsAccount.deductAccountMargin(runtime.pnl.intoUD60x18());
        // } else if (runtime.pnl.gt(SD_ZERO)) {
        //     perpsAccount.increaseMarginCollateral(usdToken, runtime.pnl.intoUD60x18());
        // }
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
        perpsMarket.skew = sd59x18(perpsMarket.skew).add(sd59x18(order.payload.sizeDelta)).intoInt256().toInt128();
        perpsMarket.size =
            ud60x18(perpsMarket.size).add(sd59x18(order.payload.sizeDelta).abs().intoUD60x18()).intoUint128();

        emit LogSettleOrder(msg.sender, runtime.accountId, runtime.marketId, order.id, runtime.newPosition);
    }
}
