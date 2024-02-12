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
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { LimitOrderSettlementStrategy } from "@zaros/markets/settlement/LimitOrderSettlementStrategy.sol";
import { LimitOrder } from "@zaros/markets/settlement/storage/LimitOrder.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract LimitOrderUpkeep is IAutomationCompatible, IStreamsLookupCompatible, BaseUpkeep {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeCast for uint256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant LIMIT_ORDER_UPKEEP_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.LimitOrderUpkeep")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.LimitOrderUpkeep
    /// @param settlementStrategy The limit order settlement strategy contract.
    struct LimitOrderUpkeepStorage {
        LimitOrderSettlementStrategy settlementStrategy;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice {LimitOrderUpkeep} UUPS initializer.
    function initialize(address forwarder, LimitOrderSettlementStrategy settlementStrategy) external initializer {
        __BaseUpkeep_init(forwarder);

        if (address(settlementStrategy) == address(0)) {
            revert Errors.ZeroInput("settlementStrategy");
        }

        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        self.settlementStrategy = settlementStrategy;
    }

    function getConfig() public view returns (address upkeepOwner, address forwarder, address settlementStrategy) {
        BaseUpkeepStorage storage baseUpkeepStorage = _getBaseUpkeepStorage();
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        upkeepOwner = owner();
        forwarder = baseUpkeepStorage.forwarder;
        settlementStrategy = address(self.settlementStrategy);
    }

    function checkUpkeep(bytes calldata checkData)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        (uint256 checkLowerBound, uint256 checkUpperBound, uint256 performLowerBound, uint256 peformUpperBound) =
            abi.decode(checkData, (uint256, uint256, uint256, uint256));

        if (checkLowerBound > checkUpperBound || performLowerBound > peformUpperBound) {
            revert Errors.InvalidBounds();
        }

        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();
        LimitOrderSettlementStrategy settlementStrategy = self.settlementStrategy;

        LimitOrder.Data[] memory limitOrders = settlementStrategy.getLimitOrders(checkLowerBound, checkUpperBound);

        if (limitOrders.length == 0) {
            return (false, bytes(""));
        }

        SettlementConfiguration.Data memory settlementConfiguration =
            settlementStrategy.getZarosSettlementConfiguration();
        SettlementConfiguration.DataStreamsCustomStrategy memory dataStreamsCustomStrategy =
            abi.decode(settlementConfiguration.data, (SettlementConfiguration.DataStreamsCustomStrategy));

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
        pure
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
        LimitOrderSettlementStrategy settlementStrategy = self.settlementStrategy;

        (bytes memory signedReport, ISettlementModule.SettlementPayload[] memory payloads) =
            abi.decode(performData, (bytes, ISettlementModule.SettlementPayload[]));
        bytes memory extraData = abi.encode(payloads);

        settlementStrategy.executeTrade(signedReport, extraData);
    }

    function _getLimitOrderUpkeepStorage() internal pure returns (LimitOrderUpkeepStorage storage self) {
        bytes32 slot = LIMIT_ORDER_UPKEEP_LOCATION;

        assembly {
            self.slot := slot
        }
    }
}
