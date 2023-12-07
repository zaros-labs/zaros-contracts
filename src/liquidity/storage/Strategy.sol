// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

library Strategy {
    string internal constant STRATEGY_DOMAIN = "fi.liquidityEngine.core.Strategy";

    struct Data {
        address handler;
        uint128 borrowCap;
        uint128 borrowedUsd;
    }

    function load(address collateralType) internal pure returns (Data storage strategy) {
        bytes32 s = keccak256(abi.encode(STRATEGY_DOMAIN, collateralType));
        assembly {
            strategy.slot := s
        }
    }

    function create(address collateralType, address strategyHandler, uint128 borrowCap) internal {
        Data storage self = load(collateralType);
        self.handler = strategyHandler;
        self.borrowCap = borrowCap;
    }

    function getBorrowData(Data storage self) internal view returns (uint128 borrowCap, uint128 borrowedUsd) {
        assembly {
            let data := sload(self.slot)
            borrowCap := shr(128, data)
            borrowedUsd := and(data, 0xffffffffffffffffffffffffffffffff)
        }
    }
}
