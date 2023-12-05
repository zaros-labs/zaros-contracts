// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

library OcoOrder {
    struct Data {
        uint128 accountId;
        int128 sizeDelta;
        uint128 price;
    }

    function load(uint256 orderId) internal view returns (Data storage ocoOrder) {
        bytes32 slot = keccak256(abi.encode("fi.zaros.external.chainlink.upkeeps.OcoOrder", orderId));
        assembly {
            ocoOrder.slot := slot
        }
    }

    function create(uint128 accountId, uint256 orderId, int128 sizeDelta, uint128 price) internal {
        Data storage self = load(orderId);

        self.accountId = accountId;
        self.sizeDelta = sizeDelta;
        self.price = price;
    }
}
