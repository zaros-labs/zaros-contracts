// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { AccountModule } from "./modules/AccountModule.sol";
import { CollateralModule } from "./modules/CollateralModule.sol";
import { MulticallModule } from "./modules/MulticallModule.sol";
import { VaultModule } from "./modules/VaultModule.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract Zaros is Ownable, AccountModule, CollateralModule, MulticallModule, VaultModule {
    // TODO: switch to UUPS
    constructor(address accountToken) {
        AccountModule.__AccountModule_init(accountToken);
    }
}
