// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { PerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";
import { LimitedMintingERC20 } from "@zaros/testnet/LimitedMintingERC20.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "./utils/ProtocolConfiguration.sol";
import {
    deployBranchs,
    getBranchsSelectors,
    getBranchUpgrades,
    getInitializables,
    getInitializePayloads
} from "./helpers/TreeProxyHelpers.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

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
    address internal accessKeyManager;
    address internal usdToken;

    function run() public broadcaster {
        tradingAccountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC", deployer);
        console.log("Trading Account NFT: ", address(tradingAccountToken));
        usdToken = vm.envAddress("USDZ");

        isTestnet = vm.envBool("IS_TESTNET");
        accessKeyManager = vm.envOr("ACCESS_KEY_MANAGER", address(0));

        address[] memory branches = deployBranchs(isTestnet);
        bytes4[][] memory branchesSelectors = getBranchsSelectors(isTestnet);

        RootProxy.BranchUpgrade[] memory branchUpgrades =
            getBranchUpgrades(branches, branchesSelectors, RootProxy.BranchUpgradeAction.Add);
        address[] memory initializables = getInitializables(branches, isTestnet);
        bytes[] memory initializePayloads =
            getInitializePayloads(deployer, address(tradingAccountToken), usdToken, accessKeyManager, isTestnet);

        RootProxy.InitParams memory initParams = RootProxy.InitParams({
            initBranches: branchUpgrades,
            initializables: initializables,
            initializePayloads: initializePayloads
        });

        perpsEngine = IPerpsEngine(address(new PerpsEngine(initParams)));
        console.log("Perps Engine Proxy: ", address(perpsEngine));
    }
}
