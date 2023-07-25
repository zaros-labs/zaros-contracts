// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsAccountModule } from "./IPerpsAccountModule.sol";
import { ISystemPerpsMarketsConfigurationModule } from "./ISystemPerpsMarketsConfigurationModule.sol";

interface IPerpsVault is IPerpsAccountModule, ISystemPerpsMarketsConfigurationModule { }
