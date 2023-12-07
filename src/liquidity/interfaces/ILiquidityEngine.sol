// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IFeatureFlagModule } from "@zaros/utils/interfaces/IFeatureFlagModule.sol";
import { IAccountModule } from "./IAccountModule.sol";
import { ICollateralModule } from "./ICollateralModule.sol";
import { IMulticallModule } from "./IMulticallModule.sol";
import { IMarketManagerModule } from "./IMarketManagerModule.sol";
import { IRewardsManagerModule } from "./IRewardsManagerModule.sol";
import { IStrategyManagerModule } from "./IStrategyManagerModule.sol";
import { IVaultModule } from "./IVaultModule.sol";

interface ILiquidityEngine is
    IFeatureFlagModule,
    IAccountModule,
    ICollateralModule,
    IMulticallModule,
    IMarketManagerModule,
    IRewardsManagerModule,
    IStrategyManagerModule,
    IVaultModule
{ }
