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
    deployBranches,
    getBranchesSelectors,
    getBranchUpgrades,
    getInitializables,
    getInitializePayloads
} from "./helpers/TreeProxyHelpers.sol";
import { RegisterUpkeep, LinkTokenInterface, AutomationRegistrarInterface } from "script/helpers/RegisterUpkeep.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

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
    address internal usdToken;
    address internal link;
    address internal automationRegistrar;

    function run() public broadcaster {
        tradingAccountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC", deployer);
        console.log("Trading Account NFT: ", address(tradingAccountToken));
        usdToken = vm.envAddress("USDZ");
        link = vm.envAddress("LINK");
        automationRegistrar = vm.envAddress("CHAINLINK_AUTOMATION_REGISTRAR");

        isTestnet = vm.envBool("IS_TESTNET");

        address[] memory branches = deployBranches(isTestnet);
        bytes4[][] memory branchesSelectors = getBranchesSelectors(isTestnet);

        RootProxy.BranchUpgrade[] memory branchUpgrades =
            getBranchUpgrades(branches, branchesSelectors, RootProxy.BranchUpgradeAction.Add);
        address[] memory initializables = getInitializables(branches);
        bytes[] memory initializePayloads = getInitializePayloads(deployer, address(tradingAccountToken), usdToken);

        RootProxy.InitParams memory initParams = RootProxy.InitParams({
            initBranches: branchUpgrades,
            initializables: initializables,
            initializePayloads: initializePayloads
        });

        perpsEngine = IPerpsEngine(address(new PerpsEngine(initParams)));
        console.log("Perps Engine: ", address(perpsEngine));

        deployRegisterUpkeep();
    }

    function deployRegisterUpkeep() internal {
        address registerUpkeepImplementation = address(new RegisterUpkeep());

        bytes memory registerUpkeepInitializeData = abi.encodeWithSelector(
            RegisterUpkeep.initialize.selector,
            deployer,
            LinkTokenInterface(link),
            AutomationRegistrarInterface(automationRegistrar)
        );

        address registerUpkeep = address(new ERC1967Proxy(registerUpkeepImplementation, registerUpkeepInitializeData));

        console.log("Register Upkeep Implementation: ", registerUpkeepImplementation);
        console.log("Register Upkeep Proxy: ", registerUpkeep);
    }
}
