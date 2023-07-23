// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

library SystemPerpsMarketConfiguration {
    bytes32 internal constant SYSTEM_PERPS_MARKET_CONFIGURATION_SLOT =
        keccak256(abi.encode("fi.zaros.markets.SystemPerpsMarketConfiguration"));

    struct Data {
        mapping(address collateralType => bool) enabledCollateralTypes;
        mapping(address perpsMarket => bool) enabledPerpsMarkets;
        address zaros;
        address zrsUsd;
    }

    function load() internal pure returns (Data storage systemPerpsMarketConfiguration) {
        bytes32 slot = SYSTEM_PERPS_MARKET_CONFIGURATION_SLOT;
        assembly {
            systemPerpsMarketConfiguration.slot := slot
        }
    }
}
