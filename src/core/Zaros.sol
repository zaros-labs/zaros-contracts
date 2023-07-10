// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { AccountModule } from "./modules/AccountModule.sol";
import { CollateralModule } from "./modules/CollateralModule.sol";
import { MulticallModule } from "./modules/MulticallModule.sol";
import { VaultModule } from "./modules/VaultModule.sol";

contract Zaros is AccountModule, CollateralModule, MulticallModule, VaultModule { }
