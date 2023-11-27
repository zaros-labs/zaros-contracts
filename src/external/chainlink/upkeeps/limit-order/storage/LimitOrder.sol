// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

library LimitOrder {
    /// @notice ERC7201 storage location.
    bytes32 internal constant LIMIT_ORDER_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.LimitOrder")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @notice The Limit Order data structure.
    /// @param price The desired execution price.
    struct Data {
        uint128 price;
        int128 sizeDelta;
    }

    function load(
        uint128 marketId,
        uint128 accountId,
        uint128 orderId
    )
        internal
        pure
        returns (Data storage limitOrder)
    {
        bytes32 slot = keccak256(abi.encode(LIMIT_ORDER_LOCATION, marketId, accountId, orderId));
        assembly {
            limitOrder.slot := slot
        }
    }

    //  function addLimitOrder(Data storage self, uint128 marketId, uint128 price, Order.Payload memory payload)
    // internal {
    //     uint128 nextLimitOrderId = ++self.nextLimitOrderId;
    //     uint256 limitOrderSlot = Order.createLimit({ id: nextLimitOrderId, price: price, payload: payload });

    //     self.limitOrdersSlotsPerMarket[marketId].set(uint256(nextLimitOrderId), limitOrderSlot);
    // }
}
