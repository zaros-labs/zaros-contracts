// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

library SystemPerpsMarketsConfiguration {
    bytes32 internal constant SYSTEM_PERPS_MARKET_CONFIGURATION_SLOT =
        keccak256(abi.encode("fi.zaros.markets.SystemPerpsMarketsConfiguration"));

    struct Data {
        mapping(address collateralType => bool) enabledCollateralTypes;
        mapping(address perpsMarket => bool) enabledPerpsMarkets;
        address zaros;
        address zrsUsd;
    }

    function load() internal pure returns (Data storage systemPerpsMarketsConfiguration) {
        bytes32 slot = SYSTEM_PERPS_MARKET_CONFIGURATION_SLOT;
        assembly {
            systemPerpsMarketsConfiguration.slot := slot
        }
    }

    function isCollateralEnabled(Data storage self, address collateralType) internal view returns (bool) {
        return self.enabledCollateralTypes[collateralType];
    }
}
