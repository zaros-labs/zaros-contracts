// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IRootProxy } from "@zaros/diamonds/interfaces/IRootProxy.sol";
import { RootProxy } from "@zaros/diamonds/RootProxy.sol";

contract PerpsEngine is RootProxy {
    constructor(IRootProxy.InitParams memory initParams) RootProxy(initParams) { }

    receive() external payable { }
}
