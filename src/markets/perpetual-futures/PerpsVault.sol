// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsVault } from "./interfaces/IPerpsVault.sol";
import { PerpsAccountModule } from "./modules/PerpsAccountModule.sol";
import { PerpsMarketConfigurationModule } from "./modules/PerpsMarketConfigurationModule.sol";

contract PerpsVault is IPerpsVault, PerpsAccountModule, PerpsMarketConfigurationModule {
    constructor(address zaros, address zrsUsd) {
        PerpsMarketConfigurationModule.__PerpsMarketConfigurationModule_init(zaros, zrsUsd);
    }
}
