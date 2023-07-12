// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

library Strategy {
    string internal constant _STRATEGY_DOMAIN = "fi.zaros.core.Strategy";

    struct Data {
        address handler;
    }

    function load(address collateralType) internal pure returns (Data storage strategy) {
        bytes32 s = keccak256(abi.encode(_STRATEGY_DOMAIN, collateralType));
        assembly {
            strategy.slot := s
        }
    }

    function create(address collateralType, address strategyHandler) internal {
        Data storage self = load(collateralType);
        self.handler = strategyHandler;
    }
}
