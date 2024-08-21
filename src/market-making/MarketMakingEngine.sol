// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { UpgradeBranch } from "@zaros/tree-proxy/branches/UpgradeBranch.sol";
import { LookupBranch } from "@zaros/tree-proxy/branches/LookupBranch.sol";
import { CreditDelegationBranch } from "./branches/CreditDelegationBranch.sol";
import { FeeDistributionBranch } from "./branches/FeeDistributionBranch.sol";
import { MarketMakingEngineConfigurationBranch } from "./branches/MarketMakingEngineConfigurationBranch.sol";
import { StabilityBranch } from "./branches/StabilityBranch.sol";
import { VaultRouterBranch } from "./branches/VaultRouterBranch.sol";

abstract contract IMarketMakingEngine is
    UpgradeBranch,
    LookupBranch,
    CreditDelegationBranch,
    FeeDistributionBranch,
    MarketMakingEngineConfigurationBranch,
    StabilityBranch,
    VaultRouterBranch
{ }

contract MarketMakingEngine is RootProxy {
    constructor(InitParams memory initParams) RootProxy(initParams) { }
}
