// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsExchange } from "./interfaces/IPerpsExchange.sol";
import { OrderModule } from "./modules/OrderModule.sol";
import { PerpsAccountModule } from "./modules/PerpsAccountModule.sol";
import { PerpsConfigurationModule } from "./modules/PerpsConfigurationModule.sol";
import { PerpsEngineModule } from "./modules/PerpsEngineModule.sol";

contract PerpsExchange is
    IPerpsExchange,
    OrderModule,
    PerpsAccountModule,
    PerpsConfigurationModule,
    PerpsEngineModule
{
    constructor(address perpsAccountToken, address rewardDistributor, address zaros) {
        PerpsConfigurationModule.__PerpsConfigurationModule_init(perpsAccountToken, rewardDistributor, zaros);
    }
}
