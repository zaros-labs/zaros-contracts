// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsExchange } from "./interfaces/IPerpsExchange.sol";
import { PerpsAccountModule } from "./modules/PerpsAccountModule.sol";
import { PerpsConfigurationModule } from "./modules/PerpsConfigurationModule.sol";

contract PerpsExchange is IPerpsExchange, PerpsAccountModule, PerpsConfigurationModule {
    constructor(address accountToken, address rewardDistributor, address zaros) {
        PerpsConfigurationModule.__PerpsConfigurationModule_init(accountToken, rewardDistributor, zaros);
    }
}
