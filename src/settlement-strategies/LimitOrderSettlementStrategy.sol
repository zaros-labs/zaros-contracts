// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { ISettlementStrategy } from "./interfaces/ISettlementStrategy.sol";

contract LimitOrderSettlementStrategy is ISettlementStrategy {
    enum Actions {
        CREATE_LIMIT_ORDER,
        CANCEL_LIMIT_ORDER
    }

    event LogCreateLimitOrder(uint128 indexed accountId, uint256 orderId, uint128 price, int128 sizeDelta);
    event LogCancelLimitOrder(uint128 indexed accountId, uint256 orderId);

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.LimitOrderUpkeep
    /// @param nextOrderId The id that will be used for the next limit order stored.
    /// @param marketId The upkeep's linked Zaros market id.
    /// @param settlementStrategyId The upkeep's linked Zaros market's settlement strategy id.
    /// @param limitOrdersIds The set of limit orders ids, used to find the limit orders to be settled.
    struct LimitOrderSettlementStrategyStorage {
        uint128 nextOrderId;
        uint128 marketId;
        uint128 settlementStrategyId;
        EnumerableSet.UintSet limitOrdersIds;
    }


    // /// @notice {LimitOrderUpkeep} UUPS initializer.
    // function initialize(
    //     address chainlinkVerifier,
    //     address forwarder,
    //     PerpsEngine perpsEngine,
    //     uint128 marketId,
    //     uint128 settlementStrategyId
    // )
    //     external
    //     initializer
    // {
    //     __BaseUpkeep_init(chainlinkVerifier, forwarder, perpsEngine);

    //     if (marketId == 0) {
    //         revert Errors.ZeroInput("marketId");
    //     }
    //     if (settlementStrategyId == 0) {
    //         revert Errors.ZeroInput("settlementStrategyId");
    //     }

    //     LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

    //     self.marketId = marketId;
    //     self.settlementStrategyId = settlementStrategyId;
    // }


    // function getConfig()
    //     public
    //     view
    //     returns (
    //         address upkeepOwner,
    //         address chainlinkVerifier,
    //         address forwarder,
    //         address perpsEngine,
    //         uint128 marketId,
    //         uint128 settlementStrategyId
    //     )
    // {
    //     BaseUpkeepStorage storage baseUpkeepStorage = _getBaseUpkeepStorage();
    //     LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

    //     upkeepOwner = owner();
    //     chainlinkVerifier = baseUpkeepStorage.chainlinkVerifier;
    //     forwarder = baseUpkeepStorage.forwarder;
    //     perpsEngine = address(baseUpkeepStorage.perpsEngine);
    //     marketId = self.marketId;
    //     settlementStrategyId = self.settlementStrategyId;
    // }


    function beforeSettlement(ISettlementModule.SettlementPayload calldata payload) external { }

    function afterSettlement() external { }


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
