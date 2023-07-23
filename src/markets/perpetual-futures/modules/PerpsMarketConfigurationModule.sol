// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsMarketConfigurationModule } from "../interfaces/IPerpsMarketConfigurationModule.sol";

contract PerpsMarketConfigurationModule is IPerpsMarketConfigurationModule {
    function setZaros(address zaros) external { }

    function setUsd(address zrsUsd) external { }

    function registerMarket(address perpsMarket) external { }
}
