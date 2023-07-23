// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsVault } from "./interfaces/IPerpsVault.sol";
import { PerpsAccountModule } from "./modules/PerpsAccountModule.sol";
import { SystemPerpsMarketConfigurationModule } from "./modules/SystemPerpsMarketConfigurationModule.sol";

contract PerpsVault is IPerpsVault, PerpsAccountModule, SystemPerpsMarketConfigurationModule {
    constructor(address zaros, address zrsUsd) {
        SystemPerpsMarketConfigurationModule.__SystemPerpsMarketConfigurationModule_init(zaros, zrsUsd);
    }
}
