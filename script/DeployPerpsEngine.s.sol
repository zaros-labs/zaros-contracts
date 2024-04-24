// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { IRootProxy } from "@zaros/tree-proxy/interfaces/IRootProxy.sol";
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { PerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { IPerpsEngine } from "@zaros/perpetuals/interfaces/IPerpsEngine.sol";
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
} from "./helpers/DiamondHelpers.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract DeployPerpsEngine is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal mockRewardDistributorAddress = address(3);
    address internal mockLiquidityEngineAddress = address(4);
    bool isTestnet;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    AccountNFT internal perpsAccountToken;
    IPerpsEngine internal perpsEngine;
    address internal accessKeyManager;
    address internal usdToken;

    function run() public broadcaster {
        perpsAccountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC", deployer);
        console.log("Perps Account NFT: ", address(perpsAccountToken));
        usdToken = vm.envAddress("USDZ");

        isTestnet = vm.envBool("IS_TESTNET");
        accessKeyManager = vm.envOr("ACCESS_KEY_MANAGER", address(0));

        address[] memory branches = deployBranchs(isTestnet);
        bytes4[][] memory branchesSelectors = getBranchsSelectors(isTestnet);

        IRootProxy.BranchUpgrade[] memory branchUpgrades =
            getBranchUpgrades(branches, branchesSelectors, IRootProxy.BranchUpgradeAction.Add);
        address[] memory initializables = getInitializables(branches, isTestnet);
        bytes[] memory initializePayloads = getInitializePayloads(
            deployer,
            address(perpsAccountToken),
            mockRewardDistributorAddress,
            usdToken,
            mockLiquidityEngineAddress,
            accessKeyManager,
            isTestnet
        );

        IRootProxy.InitParams memory initParams = IRootProxy.InitParams({
            initBranches: branchUpgrades,
            initializables: initializables,
            initializePayloads: initializePayloads
        });

        perpsEngine = IPerpsEngine(address(new PerpsEngine(initParams)));
        console.log("Perps Engine Proxy: ", address(perpsEngine));
    }
}
