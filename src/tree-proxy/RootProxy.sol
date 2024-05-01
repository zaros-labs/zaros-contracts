// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { RootUpgrade } from "./leaves/RootUpgrade.sol";
import { IRootProxy } from "./interfaces/IRootProxy.sol";

// Open Zeppelin dependencies
import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";

abstract contract RootProxy is IRootProxy, Proxy {
    using RootUpgrade for RootUpgrade.Data;

    constructor(InitParams memory initRootUpgrade) {
        RootUpgrade.Data storage rootUpgrade = RootUpgrade.load();

        rootUpgrade.upgrade(
            initRootUpgrade.initBranches, initRootUpgrade.initializables, initRootUpgrade.initializePayloads
        );
    }

    function _implementation() internal view override returns (address) {
        RootUpgrade.Data storage rootUpgrade = RootUpgrade.load();
        bytes4 functionSignature = msg.sig;

        address branch = rootUpgrade.getBranchAddress(functionSignature);
        if (branch == address(0)) revert Errors.UnsupportedFunction(functionSignature);

        return branch;
    }
}
