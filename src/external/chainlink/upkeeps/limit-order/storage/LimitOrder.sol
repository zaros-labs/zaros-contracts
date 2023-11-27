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
        uint128 accountId;
        int128 sizeDelta;
    }

    function load() internal pure returns (Data storage limitOrder) {
        bytes32 slot = keccak256(abi.encode(LIMIT_ORDER_LOCATION));
        assembly {
            limitOrder.slot := slot
        }
    }
}
