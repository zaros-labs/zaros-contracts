// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

library LimitOrder {
    /// @notice ERC7201 storage location.
    bytes32 internal constant LIMIT_ORDER_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.markets.settlement.storage.LimitOrder")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @notice The Limit Order data structure.
    /// @param price The desired execution price.
    struct Data {
        uint128 accountId;
        int128 sizeDelta;
        uint128 price;
    }

    function load(uint256 orderId) internal pure returns (Data storage limitOrder) {
        bytes32 slot = keccak256(abi.encode(LIMIT_ORDER_LOCATION, orderId));
        assembly {
            limitOrder.slot := slot
        }
    }

    function create(uint128 accountId, uint256 orderId, int128 sizeDelta, uint128 price) internal {
        Data storage self = load(orderId);

        self.accountId = accountId;
        self.sizeDelta = sizeDelta;
        self.price = price;
    }

    function reset(Data storage self) internal {
        self.accountId = 0;
        self.sizeDelta = 0;
        self.price = 0;
    }
}
