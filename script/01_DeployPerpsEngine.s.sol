// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { PerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "./utils/ProtocolConfiguration.sol";
import {
    deployBranches,
    getBranchesSelectors,
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
    AccountNFT internal tradingAccountToken;
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        address tradingAccountTokenImplementation = address(new AccountNFT());
        bytes memory tradingAccountTokenInitializeData = abi.encodeWithSelector(
            AccountNFT.initialize.selector, deployer, "Zaros Trading Accounts", "ZRS-TRADE-ACC"
        );
        tradingAccountToken = AccountNFT(
            address(new ERC1967Proxy(tradingAccountTokenImplementation, tradingAccountTokenInitializeData))
        );

        console.log("Trading Account NFT Implementation: ", tradingAccountTokenImplementation);
        console.log("Trading Account NFT Proxy: ", address(tradingAccountToken));

        isTestnet = vm.envBool("IS_TESTNET");

        address[] memory branches = deployBranches(isTestnet);
        bytes4[][] memory branchesSelectors = getBranchesSelectors(isTestnet);

        RootProxy.BranchUpgrade[] memory branchUpgrades =
            getBranchUpgrades(branches, branchesSelectors, RootProxy.BranchUpgradeAction.Add);
        address[] memory initializables = getInitializables(branches);
        bytes[] memory initializePayloads =
            getInitializePayloads(deployer, address(tradingAccountToken), USDZ_ADDRESS);

        RootProxy.InitParams memory initParams = RootProxy.InitParams({
            initBranches: branchUpgrades,
            initializables: initializables,
            initializePayloads: initializePayloads
        });

        perpsEngine = IPerpsEngine(address(new PerpsEngine(initParams)));
        console.log("Perps Engine: ", address(perpsEngine));
    }
}
