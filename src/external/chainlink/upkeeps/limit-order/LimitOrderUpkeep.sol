// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IAutomationCompatible } from "../../interfaces/IAutomationCompatible.sol";
import { IFeeManager, FeeAsset } from "../../interfaces/IFeeManager.sol";
import { ILogAutomation, Log as AutomationLog } from "../../interfaces/ILogAutomation.sol";
import { IStreamsLookupCompatible, BasicReport, PremiumReport } from "../../interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "../../interfaces/IVerifierProxy.sol";
import { BaseUpkeepUpgradeable } from "../BaseUpkeepUpgradeable.sol";
import { ChainlinkUtil } from "../../ChainlinkUtil.sol";
import { LimitOrder } from "./storage/LimitOrder.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementStrategy } from "@zaros/markets/perps/storage/SettlementStrategy.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract LimitOrderUpkeep is IAutomationCompatible, IStreamsLookupCompatible, BaseUpkeepUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;
    using LimitOrder for LimitOrder.Data;
    using SafeCast for uint256;

    enum Actions {
        CREATE_LIMIT_ORDER,
        CANCEL_LIMIT_ORDER
    }

    event LogCreateLimitOrder(uint128 indexed accountId, uint256 orderId, uint128 price, int128 sizeDelta);
    event LogCancelLimitOrder(uint128 indexed accountId, uint256 orderId);

    /// @notice ERC7201 storage location.
    bytes32 internal constant LIMIT_ORDER_UPKEEP_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.LimitOrderUpkeep")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.LimitOrderUpkeep
    /// @param nextOrderId The id that will be used for the next limit order stored.
    /// @param marketId The upkeep's linked Zaros market id.
    /// @param settlementStrategyId The upkeep's linked Zaros market's settlement strategy id.
    /// @param limitOrdersIds The set of limit orders ids, used to find the limit orders to be settled.
    struct LimitOrderUpkeepStorage {
        uint128 nextOrderId;
        uint128 marketId;
        uint128 settlementStrategyId;
        EnumerableSet.UintSet limitOrdersIds;
    }

    /// @notice {LimitOrderUpkeep} UUPS initializer.
    function initialize(
        address chainlinkVerifier,
        address forwarder,
        PerpsEngine perpsEngine,
        uint128 marketId,
        uint128 settlementStrategyId
    )
        external
        initializer
    {
        __BaseUpkeep_init(chainlinkVerifier, forwarder, perpsEngine);

        if (marketId == 0) {
            revert Errors.ZeroInput("marketId");
        }
        if (settlementStrategyId == 0) {
            revert Errors.ZeroInput("settlementStrategyId");
        }

        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        self.marketId = marketId;
        self.settlementStrategyId = settlementStrategyId;
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
            uint128 settlementStrategyId
        )
    {
        BaseUpkeepStorage storage baseUpkeepStorage = _getBaseUpkeepStorage();
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        upkeepOwner = owner();
        chainlinkVerifier = baseUpkeepStorage.chainlinkVerifier;
        forwarder = baseUpkeepStorage.forwarder;
        perpsEngine = address(baseUpkeepStorage.perpsEngine);
        marketId = self.marketId;
        settlementStrategyId = self.settlementStrategyId;
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

        BaseUpkeepStorage storage baseUpkeepStorage = _getBaseUpkeepStorage();
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();
        PerpsEngine perpsEngine = baseUpkeepStorage.perpsEngine;

        uint256 amountOfOrders =
            self.limitOrdersIds.length() > checkUpperBound ? checkUpperBound : self.limitOrdersIds.length();

        if (amountOfOrders == 0) {
            return (upkeepNeeded, performData);
        }

        LimitOrder.Data[] memory limitOrders = new LimitOrder.Data[](amountOfOrders);

        for (uint256 i = checkLowerBound; i < amountOfOrders; i++) {
            uint256 orderId = self.limitOrdersIds.at(i);
            limitOrders[i] = LimitOrder.load(orderId);
        }

        SettlementStrategy.Data memory settlementStrategy =
            perpsEngine.getSettlementStrategy(self.marketId, self.settlementStrategyId);
        SettlementStrategy.DataStreamsCustomStrategy memory dataStreamsCustomStrategy =
            abi.decode(settlementStrategy.data, (SettlementStrategy.DataStreamsCustomStrategy));

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
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();
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

    function beforeSettlement(ISettlementModule.SettlementPayload calldata payload) external override { }

    function afterSettlement() external override onlyPerpsEngine { }

    function invoke(uint128 accountId, bytes calldata extraData) external override onlyPerpsEngine {
        (Actions action) = abi.decode(extraData[0:8], (Actions));
        bytes memory functionData = extraData[8:];

        if (action == Actions.CREATE_LIMIT_ORDER) {
            (int128 sizeDelta, uint128 price) = abi.decode(functionData, (int128, uint128));

            _createLimitOrder(accountId, sizeDelta, price);
        } else if (action == Actions.CANCEL_LIMIT_ORDER) {
            (uint256 orderId) = abi.decode(functionData, (uint256));

            _cancelLimitOrder(accountId, orderId);
        } else {
            revert Errors.InvalidSettlementStrategyAction();
        }
    }

    function performUpkeep(bytes calldata performData) external override onlyForwarder {
        (bytes memory signedReport, ISettlementModule.SettlementPayload[] memory payloads) =
            abi.decode(performData, (bytes, ISettlementModule.SettlementPayload[]));

        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();
        (uint128 marketId, uint128 settlementStrategyId) = (self.marketId, self.settlementStrategyId);
        (
            PerpsEngine perpsEngine,
            ISettlementModule.SettlementPayload[] memory payloads,
            bytes memory verifiedReportData
        ) = _preparePerformData(marketId, performData);

        perpsEngine.settleCustomTriggers(marketId, settlementStrategyId, payloads, verifiedReportData);
    }

    function _getLimitOrderUpkeepStorage() internal pure returns (LimitOrderUpkeepStorage storage self) {
        bytes32 slot = LIMIT_ORDER_UPKEEP_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    function _createLimitOrder(uint128 accountId, int128 sizeDelta, uint128 price) internal {
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        uint256 orderId = ++self.nextOrderId;

        // There should never be a duplicate order id, but let's make sure anyway.
        assert(!self.limitOrdersIds.contains(orderId));
        self.limitOrdersIds.add(orderId);

        LimitOrder.create({ accountId: accountId, orderId: orderId, sizeDelta: sizeDelta, price: price });

        emit LogCreateLimitOrder(accountId, orderId, price, sizeDelta);
    }

    function _cancelLimitOrder(uint128 accountId, uint256 orderId) internal {
        LimitOrder.Data storage limitOrder = LimitOrder.load(orderId);
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        if (accountId != limitOrder.accountId) {
            revert Errors.LimitOrderInvalidAccountId(accountId, limitOrder.accountId);
        }

        limitOrder.reset();
        self.limitOrdersIds.remove(orderId);

        emit LogCancelLimitOrder(accountId, orderId);
    }
}
