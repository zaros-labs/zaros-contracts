// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsAccountModule } from "./IPerpsAccountModule.sol";
import { ISystemPerpsMarketConfigurationModule } from "./ISystemPerpsMarketConfigurationModule.sol";

interface IPerpsVault is IPerpsAccountModule, ISystemPerpsMarketConfigurationModule { }
