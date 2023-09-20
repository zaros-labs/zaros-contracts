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
import { PerpsConfiguration } from "../storage/PerpsConfiguration.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

abstract contract SettlementEngineModule is ISettlementEngineModule, ILogAutomation, IStreamsLookupCompatible {
    using SafeCast for uint256;

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
        (uint8 orderId, Order.Data memory order) = abi.decode(log.data, (uint8, Order.Data));
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
        (uint8 orderId,) = abi.decode(extraData, (uint8, Order.Data));

        // _settleOrder(accountId, marketId, orderId, verifiedReport);
    }

    function _getReport(bytes memory report) internal pure returns (BasicReport memory) {
        return abi.decode(report, (BasicReport));
    }

    function _settleOrder() internal { }
}
