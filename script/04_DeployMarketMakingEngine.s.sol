// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { IMarketMakingEngine, MarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { BaseScript } from "script/Base.s.sol";
import { ProtocolConfiguration } from "script/utils/ProtocolConfiguration.sol";
import {
    getInitializables,
    getInitializePayloads,
    getBranchUpgrades,
    deployMarketMakingEngineBranches,
    getMarketMakerBranchesSelectors
} from "script/utils/TreeProxyUtils.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract DeployMarketMakingEngine is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IMarketMakingEngine internal marketMakingEngine;

    function run() public broadcaster {
        // branches and selectors setup
        address[] memory mmBranches = deployMarketMakingEngineBranches();
        bytes4[][] memory mmBranchesSelectors = getMarketMakerBranchesSelectors();
        RootProxy.BranchUpgrade[] memory mmBranchUpgrades =
            getBranchUpgrades(mmBranches, mmBranchesSelectors, RootProxy.BranchUpgradeAction.Add);

        // init params setup
        address[] memory initializables = getInitializables(mmBranches);
        bytes[] memory initializePayloads = getInitializePayloads(deployer);
        RootProxy.InitParams memory mmEngineInitParams = RootProxy.InitParams({
            initBranches: mmBranchUpgrades,
            initializables: initializables,
            initializePayloads: initializePayloads
        });

        console.log("**************************");
        console.log("Deploying Market Making Engine...");
        console.log("**************************");

        // deploy market making engine
        marketMakingEngine = IMarketMakingEngine(address(new MarketMakingEngine(mmEngineInitParams)));

        console.log("Success! Market Making Engine:");
        console.log("\n");
        console.log(address(marketMakingEngine));
    }
}
