// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IDiamondCutModule } from "@zaros/diamonds/interfaces/IDiamondCutModule.sol";
import { IDiamondLoupeModule } from "@zaros/diamonds/interfaces/IDiamondLoupeModule.sol";
import { IGlobalConfigurationModuleTestnet } from "./IGlobalConfigurationModuleTestnet.sol";
import { ILiquidationModule } from "@zaros/markets/perps/interfaces/ILiquidationModule.sol";
import { IOrderModule } from "@zaros/markets/perps/interfaces/IOrderModule.sol";
import { IPerpMarketModule } from "@zaros/markets/perps/interfaces/IPerpMarketModule.sol";
import { IPerpsAccountModuleTestnet } from "./IPerpsAccountModuleTestnet.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";

interface IPerpsEngineTestnet is
    IDiamondCutModule,
    IDiamondLoupeModule,
    IGlobalConfigurationModuleTestnet,
    ILiquidationModule,
    IOrderModule,
    IPerpMarketModule,
    IPerpsAccountModuleTestnet,
    ISettlementModule
{ }
