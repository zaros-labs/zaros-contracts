// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { FeatureFlagModule } from "@zaros/utils/modules/FeatureFlagModule.sol";
import { AccountModule } from "./modules/AccountModule.sol";
import { CollateralModule } from "./modules/CollateralModule.sol";
import { MarketManagerModule } from "./modules/MarketManagerModule.sol";
import { MulticallModule } from "./modules/MulticallModule.sol";
import { RewardsManagerModule } from "./modules/RewardsManagerModule.sol";
import { StrategyManagerModule } from "./modules/StrategyManagerModule.sol";
import { VaultModule } from "./modules/VaultModule.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

// TODO: re-add MulticallModule, VaultModule, StrategyManagerModule
contract Zaros is
    Ownable,
    FeatureFlagModule,
    AccountModule,
    CollateralModule,
    MarketManagerModule,
    RewardsManagerModule
{
    // TODO: switch to Diamonds
    constructor(address accountToken, address zrsUsd) {
        AccountModule.__AccountModule_init(accountToken);
        MarketManagerModule.__MarketManagerModule_init(zrsUsd);
    }
}
