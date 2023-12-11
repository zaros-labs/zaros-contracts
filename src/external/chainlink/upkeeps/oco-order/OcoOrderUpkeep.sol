// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IAutomationCompatible } from "../../interfaces/IAutomationCompatible.sol";
import { IFeeManager, FeeAsset } from "../../interfaces/IFeeManager.sol";
import { ILogAutomation, Log as AutomationLog } from "../../interfaces/ILogAutomation.sol";
import { IStreamsLookupCompatible, BasicReport, PremiumReport } from "../../interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "../../interfaces/IVerifierProxy.sol";
import { BaseUpkeep } from "../BaseUpkeep.sol";
import { ChainlinkUtil } from "../../ChainlinkUtil.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { OcoOrderSettlementStrategy } from "@zaros/markets/settlement/OcoOrderSettlementStrategy.sol";
import { OcoOrder } from "@zaros/markets/settlement/storage/OcoOrder.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
// import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract OcoOrderUpkeep is IAutomationCompatible, IStreamsLookupCompatible, BaseUpkeep {
    using SafeCast for uint256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant OCO_ORDER_UPKEEP_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.OcoOrderUpkeep")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.OcoOrderUpkeep
    struct OcoOrderUpkeepStorage {
        OcoOrderSettlementStrategy settlementStrategy;
    }

    /// @notice {OcoOrderUpkeep} UUPS initializer.
    function initialize(address forwarder, OcoOrderSettlementStrategy settlementStrategy) external initializer {
        __BaseUpkeep_init(forwarder);

        if (address(settlementStrategy) == address(0)) {
            revert Errors.ZeroInput("settlementStrategy");
        }

        OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();

        self.settlementStrategy = settlementStrategy;
    }

    function getConfig() public view returns (address upkeepOwner, address forwarder, address settlementStrategy) {
        BaseUpkeepStorage storage baseUpkeepStorage = _getBaseUpkeepStorage();
        OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();

        upkeepOwner = owner();
        forwarder = baseUpkeepStorage.forwarder;
        settlementStrategy = address(self.settlementStrategy);
    }

    function checkUpkeep(bytes calldata checkData)
        external
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        (uint256 checkLowerBound, uint256 checkUpperBound, uint256 performLowerBound, uint256 performUpperBound) =
            abi.decode(checkData, (uint256, uint256, uint256, uint256));

        if (checkLowerBound > checkUpperBound || performLowerBound > performUpperBound) {
            revert Errors.InvalidBounds();
        }

        OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();
        OcoOrderSettlementStrategy settlementStrategy = self.settlementStrategy;

        OcoOrder.Data[] memory ocoOrders = settlementStrategy.getOcoOrders(checkLowerBound, checkUpperBound);

        if (ocoOrders.length == 0) {
            return (false, bytes(""));
        }

        SettlementConfiguration.DataStreamsCustomStrategy memory dataStreamsCustomStrategy =
            settlementStrategy.getZarosSettlementConfiguration();

        string[] memory feedsParam = new string[](1);
        feedsParam[0] = dataStreamsCustomStrategy.streamId;
        bytes memory extraData =
            abi.encode(ocoOrders, performLowerBound, performUpperBound, dataStreamsCustomStrategy.isPremium);

        revert StreamsLookup(
            dataStreamsCustomStrategy.feedLabel,
            feedsParam,
            dataStreamsCustomStrategy.queryLabel,
            block.timestamp,
            extraData
        );
    }

    function checkCallback(
        bytes[] calldata values,
        bytes calldata extraData
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        ISettlementModule.SettlementPayload[] memory payloads = new ISettlementModule.SettlementPayload[](0);

        (OcoOrder.Data[] memory ocoOrders, uint256 performLowerBound, uint256 performUpperBound, bool isPremiumReport) =
            abi.decode(extraData, (OcoOrder.Data[], uint256, uint256, bool));
        uint256 ordersToIterate = ocoOrders.length > performUpperBound ? performUpperBound : ocoOrders.length;

        bytes memory reportData = ChainlinkUtil.getReportData(values[0]);

        UD60x18 reportPrice = ChainlinkUtil.getReportPriceUd60x18(reportData, REPORT_PRICE_DECIMALS, isPremiumReport);

        for (uint256 i = performLowerBound; i < ordersToIterate; i++) {
            OcoOrder.TakeProfit memory takeProfit = ocoOrders[i].takeProfit;
            OcoOrder.StopLoss memory stopLoss = ocoOrders[i].stopLoss;

            bool isLongPosition = takeProfit.sizeDelta < 0 || stopLoss.sizeDelta < 0;

            bool isTpFillable = (
                isLongPosition ? ud60x18(takeProfit.price).gte(reportPrice) : ud60x18(takeProfit.price).lte(reportPrice)
            ) && takeProfit.price != 0;

            bool isStopLossFillable = (
                isLongPosition ? ud60x18(stopLoss.price).lte(reportPrice) : ud60x18(stopLoss.price).gte(reportPrice)
            ) && stopLoss.price != 0;

            if (isTpFillable || isStopLossFillable) {
                payloads[payloads.length] = ISettlementModule.SettlementPayload({
                    accountId: ocoOrders[i].accountId,
                    sizeDelta: isTpFillable ? takeProfit.sizeDelta : stopLoss.sizeDelta
                });
            }
        }

        if (payloads.length > 0) {
            upkeepNeeded = true;
            performData = abi.encode(values[0], payloads);
        }
    }

    function performUpkeep(bytes calldata performData) external override onlyForwarder {
        OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();
        OcoOrderSettlementStrategy settlementStrategy = self.settlementStrategy;

        (bytes memory signedReport, ISettlementModule.SettlementPayload[] memory payloads) =
            abi.decode(performData, (bytes, ISettlementModule.SettlementPayload[]));

        settlementStrategy.settle(signedReport, payloads);
    }

    function _getOcoOrderUpkeepStorage() internal pure returns (OcoOrderUpkeepStorage storage self) {
        bytes32 slot = OCO_ORDER_UPKEEP_LOCATION;

        assembly {
            self.slot := slot
        }
    }
}
