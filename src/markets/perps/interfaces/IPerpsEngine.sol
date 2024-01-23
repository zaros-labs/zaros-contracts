// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IGlobalConfigurationModule } from "./IGlobalConfigurationModule.sol";
import { IOrderModule } from "./IOrderModule.sol";
import { IPerpMarketModule } from "./IPerpMarketModule.sol";
import { IPerpsAccountModule } from "./IPerpsAccountModule.sol";
import { ISettlementModule } from "./ISettlementModule.sol";

interface IPerpsEngine is
    IGlobalConfigurationModule,
    IOrderModule,
    IPerpMarketModule,
    IPerpsAccountModule,
    ISettlementModule
{ }
