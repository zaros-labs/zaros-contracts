// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsExchange } from "./interfaces/IPerpsExchange.sol";
import { OrderModule } from "./modules/OrderModule.sol";
import { PerpsAccountModule } from "./modules/PerpsAccountModule.sol";
import { PerpsConfigurationModule } from "./modules/PerpsConfigurationModule.sol";
import { PerpsMarketModule } from "./modules/PerpsMarketModule.sol";
import { SettlementEngineModule } from "./modules/SettlementEngineModule.sol";

contract PerpsExchange is
    IPerpsExchange,
    OrderModule,
    PerpsAccountModule,
    PerpsConfigurationModule,
    PerpsMarketModule,
    SettlementEngineModule
{
    constructor(address chainlinkVerifier, address perpsAccountToken, address rewardDistributor, address zaros) {
        PerpsConfigurationModule.__PerpsConfigurationModule_init(
            chainlinkVerifier, perpsAccountToken, rewardDistributor, zaros
        );
    }
}
