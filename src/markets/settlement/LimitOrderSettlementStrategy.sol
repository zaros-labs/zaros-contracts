// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { DataStreamsSettlementStrategy } from "./DataStreamsSettlementStrategy.sol";
import { LimitOrder } from "./storage/LimitOrder.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

contract LimitOrderSettlementStrategy is DataStreamsSettlementStrategy {
    using EnumerableSet for EnumerableSet.UintSet;
    using LimitOrder for LimitOrder.Data;

    enum Actions {
        CREATE_LIMIT_ORDER,
        CANCEL_LIMIT_ORDER
    }

    event LogCreateLimitOrder(uint128 indexed accountId, uint256 orderId, uint128 price, int128 sizeDelta);
    event LogCancelLimitOrder(uint128 indexed accountId, uint256 orderId);

    /// @notice ERC7201 storage location.
    bytes32 internal constant LIMIT_ORDER_SETTLEMENT_STRATEGY_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.markets.settlement.LimitOrderSettlementStrategy")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.markets.settlement.LimitOrderSettlementStrategy
    /// @param nextOrderId The id that will be used for the next limit order stored.
    /// @param limitOrdersIds The set of limit orders ids, used to find the limit orders to be settled.
    struct LimitOrderSettlementStrategyStorage {
        uint128 nextOrderId;
        EnumerableSet.UintSet limitOrdersIds;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice {LimitOrderSettlementStrategy} UUPS initializer.
    function initialize(IPerpsEngine perpsEngine, uint128 marketId, uint128 settlementId) external initializer {
        __DataStreamsSettlementStrategy_init(perpsEngine, marketId, settlementId);
    }

    function getLimitOrders(
        uint256 lowerBound,
        uint256 upperBound
    )
        external
        view
        returns (LimitOrder.Data[] memory)
    {
        LimitOrderSettlementStrategyStorage storage self = _getLimitOrderSettlementStrategyStorage();

        uint256 amountOfOrders = self.limitOrdersIds.length() > lowerBound ? upperBound : self.limitOrdersIds.length();
        LimitOrder.Data[] memory limitOrders = new LimitOrder.Data[](amountOfOrders);

        if (amountOfOrders == 0) {
            return limitOrders;
        }

        for (uint256 i = lowerBound; i < amountOfOrders; i++) {
            uint256 orderId = self.limitOrdersIds.at(i);
            limitOrders[i] = LimitOrder.load(orderId);
        }

        return limitOrders;
    }

    function beforeSettlement(ISettlementModule.SettlementPayload calldata payload) external { }

    function afterSettlement() external { }

    function dispatch(uint128 accountId, bytes calldata extraData) external override onlyPerpsEngine {
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

    function settle(bytes calldata signedReport, bytes calldata extraData) external override onlyRegisteredKeeper {
        DataStreamsSettlementStrategyStorage storage dataStreamsCustomSettlementStrategyStorage =
            _getDataStreamsSettlementStrategyStorage();
        (IPerpsEngine perpsEngine, uint128 marketId, uint128 settlementId) = (
            dataStreamsCustomSettlementStrategyStorage.perpsEngine,
            dataStreamsCustomSettlementStrategyStorage.marketId,
            dataStreamsCustomSettlementStrategyStorage.settlementId
        );

        ISettlementModule.SettlementPayload[] memory payloads =
            abi.decode(extraData, (ISettlementModule.SettlementPayload[]));

        perpsEngine.settleCustomOrders(marketId, settlementId, payloads, signedReport);
    }

    function _getLimitOrderSettlementStrategyStorage()
        internal
        pure
        returns (LimitOrderSettlementStrategyStorage storage self)
    {
        bytes32 slot = LIMIT_ORDER_SETTLEMENT_STRATEGY_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    function _createLimitOrder(uint128 accountId, int128 sizeDelta, uint128 price) internal {
        LimitOrderSettlementStrategyStorage storage self = _getLimitOrderSettlementStrategyStorage();

        uint256 orderId = ++self.nextOrderId;

        // There should never be a duplicate order id, but let's make sure anyway.
        assert(!self.limitOrdersIds.contains(orderId));
        self.limitOrdersIds.add(orderId);

        LimitOrder.create({ accountId: accountId, orderId: orderId, sizeDelta: sizeDelta, price: price });

        emit LogCreateLimitOrder(accountId, orderId, price, sizeDelta);
    }

    function _cancelLimitOrder(uint128 accountId, uint256 orderId) internal {
        LimitOrder.Data storage limitOrder = LimitOrder.load(orderId);
        LimitOrderSettlementStrategyStorage storage self = _getLimitOrderSettlementStrategyStorage();

        if (accountId != limitOrder.accountId) {
            revert Errors.LimitOrderInvalidAccountId(accountId, limitOrder.accountId);
        }

        limitOrder.reset();
        self.limitOrdersIds.remove(orderId);

        emit LogCancelLimitOrder(accountId, orderId);
    }
}
