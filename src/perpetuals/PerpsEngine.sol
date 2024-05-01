// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";

contract PerpsEngine is RootProxy {
    constructor(InitParams memory initParams) RootProxy(initParams) { }

    receive() external payable { }
}
