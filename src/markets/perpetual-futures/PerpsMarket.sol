// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsMarket } from "./interfaces/IPerpsMarket.sol";
import { OrderModule } from "./modules/OrderModule.sol";
import { Position } from "./storage/Position.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract PerpsMarket is IPerpsMarket, OrderModule {
    function name() external view returns (string memory) { }

    function symbol() external view returns (string memory) { }

    function skew() external view returns (SD59x18) { }

    function size() external view returns (UD60x18) { }

    function indexPrice() external view returns (UD60x18) { }

    function oracle() external view returns (address) { }

    function fundingRate() external view returns (SD59x18) { }

    function fundingVelocity() external view returns (SD59x18) { }

    function getOpenPosition(address account) external view returns (Position.Data memory) { }

    function setPerpsVault(address perpsVault) external { }
}
