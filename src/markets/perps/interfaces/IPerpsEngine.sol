// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IPerpsAccountModule } from "./IPerpsAccountModule.sol";
import { IGlobalConfigurationModule } from "./IGlobalConfigurationModule.sol";

/// @title Zaros Perps Engine.
interface IPerpsEngine is IPerpsAccountModule, IGlobalConfigurationModule { }
