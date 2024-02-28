// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { IDiamond } from "@zaros/diamonds/interfaces/IDiamond.sol";
import { Diamond } from "@zaros/diamonds/Diamond.sol";
import { LiquidationUpkeep } from "@zaros/external/chainlink/upkeeps/liquidation/LiquidationUpkeep.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { LimitedMintingERC20 } from "testnet/LimitedMintingERC20.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "./utils/ProtocolConfiguration.sol";
import {
    deployModules,
    getModulesSelectors,
    getFacetCuts,
    getInitializables,
    getInitializePayloads
} from "./helpers/DiamondHelpers.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

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

        address[] memory modules = deployModules(isTestnet);
        bytes4[][] memory modulesSelectors = getModulesSelectors(isTestnet);

        IDiamond.FacetCut[] memory facetCuts = getFacetCuts(modules, modulesSelectors, IDiamond.FacetCutAction.Add);
        address[] memory initializables = getInitializables(modules, isTestnet);
        bytes[] memory initializePayloads = getInitializePayloads(
            deployer,
            address(perpsAccountToken),
            mockRewardDistributorAddress,
            usdToken,
            mockLiquidityEngineAddress,
            accessKeyManager,
            isTestnet
        );

        IDiamond.InitParams memory initParams = IDiamond.InitParams({
            baseFacets: facetCuts,
            initializables: initializables,
            initializePayloads: initializePayloads
        });

        perpsEngine = IPerpsEngine(address(new PerpsEngine(initParams)));
        console.log("Perps Engine Proxy: ", address(perpsEngine));
    }
}
