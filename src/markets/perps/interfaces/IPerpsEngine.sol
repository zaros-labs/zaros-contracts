// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsAccountModule } from "./IPerpsAccountModule.sol";
import { IPerpsConfigurationModule } from "./IPerpsConfigurationModule.sol";

/// @title Zaros Perps Engine.
interface IPerpsEngine is IPerpsAccountModule, IPerpsConfigurationModule { }
