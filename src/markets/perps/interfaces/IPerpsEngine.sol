// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IDiamondCutModule } from "@zaros/diamonds/interfaces/IDiamondCutModule.sol";
import { IDiamondLoupeModule } from "@zaros/diamonds/interfaces/IDiamondLoupeModule.sol";
import { IGlobalConfigurationModule } from "./IGlobalConfigurationModule.sol";
import { ILiquidationModule } from "./ILiquidationModule.sol";
import { IOrderModule } from "./IOrderModule.sol";
import { IPerpMarketModule } from "./IPerpMarketModule.sol";
import { IPerpsAccountModule } from "./IPerpsAccountModule.sol";
import { ISettlementModule } from "./ISettlementModule.sol";

interface IPerpsEngine is
    IDiamondCutModule,
    IDiamondLoupeModule,
    IGlobalConfigurationModule,
    ILiquidationModule,
    IOrderModule,
    IPerpMarketModule,
    IPerpsAccountModule,
    ISettlementModule
{ }
