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
        uint128 marketId;
        uint128 accountId;
        uint128 price;
        int128 sizeDelta;
        string streamId;
    }

    function load(uint256 orderId) internal pure returns (Data storage limitOrder) {
        bytes32 slot = keccak256(abi.encode(LIMIT_ORDER_LOCATION, orderId));
        assembly {
            limitOrder.slot := slot
        }
    }

    function create(
        uint128 marketId,
        uint128 accountId,
        uint256 orderId,
        uint128 price,
        int128 sizeDelta,
        string memory streamId
    )
        internal
    {
        Data storage self = load(orderId);

        self.marketId = marketId;
        self.accountId = accountId;
        self.price = price;
        self.sizeDelta = sizeDelta;
        self.streamId = streamId;
    }
}
