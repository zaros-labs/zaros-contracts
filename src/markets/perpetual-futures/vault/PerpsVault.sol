// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsVault } from "./interfaces/IPerpsVault.sol";
import { PerpsAccountModule } from "./modules/PerpsAccountModule.sol";
import { SystemPerpsMarketsConfigurationModule } from "./modules/SystemPerpsMarketsConfigurationModule.sol";

contract PerpsVault is IPerpsVault, PerpsAccountModule, SystemPerpsMarketsConfigurationModule {
    constructor(address zaros, address zrsUsd, address sFrxEthRewardDistributor, address usdcRewardDistributor) {
        SystemPerpsMarketsConfigurationModule.__SystemPerpsMarketsConfigurationModule_init(
            zaros, zrsUsd, sFrxEthRewardDistributor, usdcRewardDistributor
        );
    }
}
