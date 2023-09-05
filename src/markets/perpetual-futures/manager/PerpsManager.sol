// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsManager } from "./interfaces/IPerpsManager.sol";
import { PerpsAccountModule } from "./modules/PerpsAccountModule.sol";
import { SystemPerpsMarketsConfigurationModule } from "./modules/SystemPerpsMarketsConfigurationModule.sol";

contract PerpsManager is IPerpsManager, PerpsAccountModule, SystemPerpsMarketsConfigurationModule {
    constructor(address zaros, address zrsUsd, address rewardDistributor) {
        SystemPerpsMarketsConfigurationModule.__SystemPerpsMarketsConfigurationModule_init(
            zaros, zrsUsd, rewardDistributor
        );
    }
}
