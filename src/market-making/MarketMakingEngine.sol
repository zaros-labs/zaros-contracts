// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { UpgradeBranch } from "@zaros/tree-proxy/branches/UpgradeBranch.sol";
import { LookupBranch } from "@zaros/tree-proxy/branches/LookupBranch.sol";

abstract contract IMarketMakingEngine is UpgradeBranch, LookupBranch { }

contract MarketMakingEngine is RootProxy {
    constructor(InitParams memory initParams) RootProxy(initParams) { }
}
