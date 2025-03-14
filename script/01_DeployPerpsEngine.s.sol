// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

// Zaros dependencies
import { TradingAccountNFT } from "@zaros/trading-account-nft/TradingAccountNFT.sol";
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { PerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "./utils/ProtocolConfiguration.sol";
import {
    deployPerpsEngineBranches,
    getPerpsEngineBranchesSelectors,
    getBranchUpgrades,
    getInitializables,
    getInitializePayloads
} from "./utils/TreeProxyUtils.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployPerpsEngine is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    bool internal isTestnet;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    TradingAccountNFT internal tradingAccountToken;
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        isTestnet = vm.envBool("IS_TESTNET");

        console.log("**************************");
        console.log("Environment variables:");
        console.log("isTestnet: ", isTestnet);
        console.log("**************************");

        console.log("**************************");
        console.log("Deploying Trading Account Token...");
        console.log("**************************");

        address tradingAccountTokenImplementation = address(new TradingAccountNFT());
        bytes memory tradingAccountTokenInitializeData = abi.encodeWithSelector(
            TradingAccountNFT.initialize.selector, deployer, "Zaros Trading Accounts", "ZRS-TRADE-ACC"
        );
        tradingAccountToken = TradingAccountNFT(
            address(new ERC1967Proxy(tradingAccountTokenImplementation, tradingAccountTokenInitializeData))
        );

        console.log("Trading Account NFT Implementation: ", tradingAccountTokenImplementation);
        console.log("Trading Account NFT Proxy: ", address(tradingAccountToken));

        console.log("Success! Deployed Trading Account Token.");
        console.log("\n");

        address[] memory branches = deployPerpsEngineBranches(isTestnet);
        bytes4[][] memory branchesSelectors = getPerpsEngineBranchesSelectors(isTestnet);

        RootProxy.BranchUpgrade[] memory branchUpgrades =
            getBranchUpgrades(branches, branchesSelectors, RootProxy.BranchUpgradeAction.Add);
        address[] memory initializables = getInitializables(branches);
        bytes[] memory initializePayloads = getInitializePayloads(deployer);

        RootProxy.InitParams memory initParams = RootProxy.InitParams({
            initBranches: branchUpgrades,
            initializables: initializables,
            initializePayloads: initializePayloads
        });

        console.log("**************************");
        console.log("Deploying Perps Engine...");
        console.log("**************************");

        perpsEngine = IPerpsEngine(address(new PerpsEngine(initParams)));
        console.log("Perps Engine: ", address(perpsEngine));

        console.log("Success! Deployed Perps Engine.");
        console.log("\n");
    }
}
