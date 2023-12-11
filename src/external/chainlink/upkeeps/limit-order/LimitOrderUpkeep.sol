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
import { LimitOrder } from "./storage/LimitOrder.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { ISettlementStrategy } from "@zaros/markets/settlement/interfaces/ISettlementStrategy.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract LimitOrderUpkeep is IAutomationCompatible, IStreamsLookupCompatible, BaseUpkeep {
    using EnumerableSet for EnumerableSet.UintSet;
    using LimitOrder for LimitOrder.Data;
    using SafeCast for uint256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant LIMIT_ORDER_UPKEEP_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.LimitOrderUpkeep")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.LimitOrderUpkeep
    /// @param settlementStrategy The settlement strategy contract.
    struct LimitOrderUpkeepStorage {
        ISettlementStrategy settlementStrategy;
    }

    /// @notice {LimitOrderUpkeep} UUPS initializer.
    function initialize(
        address chainlinkVerifier,
        address forwarder,
        PerpsEngine perpsEngine,
        uint128 marketId,
        uint128 settlementId
    )
        external
        initializer
    {
        __BaseUpkeep_init(chainlinkVerifier, forwarder, perpsEngine);

        if (marketId == 0) {
            revert Errors.ZeroInput("marketId");
        }
        if (settlementId == 0) {
            revert Errors.ZeroInput("settlementId");
        }

        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        self.marketId = marketId;
        self.settlementId = settlementId;
    }

    function getConfig()
        public
        view
        returns (
            address upkeepOwner,
            address chainlinkVerifier,
            address forwarder,
            address perpsEngine,
            uint128 marketId,
            uint128 settlementId
        )
    {
        BaseUpkeepStorage storage baseUpkeepStorage = _getBaseUpkeepStorage();
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        upkeepOwner = owner();
        chainlinkVerifier = baseUpkeepStorage.chainlinkVerifier;
        forwarder = baseUpkeepStorage.forwarder;
        perpsEngine = address(baseUpkeepStorage.perpsEngine);
        marketId = self.marketId;
        settlementId = self.settlementId;
    }

    function checkUpkeep(bytes calldata checkData)
        external
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        (uint256 checkLowerBound, uint256 checkUpperBound, uint256 performLowerBound, uint256 peformUpperBound) =
            abi.decode(checkData, (uint256, uint256, uint256, uint256));

        if (checkLowerBound > checkUpperBound || performLowerBound > peformUpperBound) {
            revert Errors.InvalidBounds();
        }

        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();
        ISettlementStrategy settlementStrategy = self.settlementStrategy;

        LimitOrder.Data[] memory limitOrders = settlementStrategy.getLimitOrders(checkLowerBound, checkUpperBound);

        SettlementConfiguration.DataStreamsCustomStrategy memory dataStreamsCustomStrategy =
            settlementStrategy.getZarosSettlementConfiguration();

        string[] memory feedsParam = new string[](1);
        feedsParam[0] = dataStreamsCustomStrategy.streamId;
        bytes memory extraData =
            abi.encode(limitOrders, performLowerBound, peformUpperBound, dataStreamsCustomStrategy.isPremium);

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

        (
            LimitOrder.Data[] memory limitOrders,
            uint256 performLowerBound,
            uint256 performUpperBound,
            bool isPremiumReport
        ) = abi.decode(extraData, (LimitOrder.Data[], uint256, uint256, bool));
        uint256 ordersToIterate = limitOrders.length > performUpperBound ? performUpperBound : limitOrders.length;

        bytes memory signedReport = values[0];
        bytes memory reportData = ChainlinkUtil.getReportData(signedReport);

        UD60x18 reportPrice = ChainlinkUtil.getReportPriceUd60x18(reportData, REPORT_PRICE_DECIMALS, isPremiumReport);

        for (uint256 i = performLowerBound; i < ordersToIterate; i++) {
            LimitOrder.Data memory limitOrder = limitOrders[i];
            // TODO: store decimals per market?
            UD60x18 orderPrice = ud60x18(limitOrder.price);

            bool isOrderFillable = (
                limitOrder.sizeDelta > 0 && reportPrice.lte(orderPrice)
                    || (limitOrder.sizeDelta < 0 && reportPrice.gte(orderPrice))
            );

            if (isOrderFillable) {
                payloads[payloads.length] = ISettlementModule.SettlementPayload({
                    accountId: limitOrder.accountId,
                    sizeDelta: limitOrder.sizeDelta
                });
            }
        }

        if (payloads.length > 0) {
            upkeepNeeded = true;
            performData = abi.encode(signedReport, payloads);
        }
    }

    function performUpkeep(bytes calldata performData) external override onlyForwarder {
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();
        ISettlementStrategy settlementStrategy = self.settlementStrategy;

        (bytes memory signedReport, ISettlementModule.SettlementPayload[] memory payloads) =
            abi.decode(performData, (bytes, ISettlementModule.SettlementPayload[]));

        settlementStrategy.settle(signedReport, payloads);
    }

    function _getLimitOrderUpkeepStorage() internal pure returns (LimitOrderUpkeepStorage storage self) {
        bytes32 slot = LIMIT_ORDER_UPKEEP_LOCATION;

        assembly {
            self.slot := slot
        }
    }
}
