// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { IDiamond } from "@zaros/diamonds/interfaces/IDiamond.sol";
import { Diamond } from "@zaros/diamonds/Diamond.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { USDToken } from "@zaros/usd/USDToken.sol";
import { BaseScript } from "./Base.s.sol";
import {
    deployModules,
    getModulesSelectors,
    getFacetCuts,
    getInitializables,
    getInitializePayloads
} from "./utils/DiamondHelpers.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
// Forge dependencies
import "forge-std/console.sol";

contract DeployAlphaPerpsEngine is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal chainlinkForwarder;
    address internal chainlinkVerifier;
    address internal mockRewardDistributorAddress = address(3);
    address internal mockLiquidityEngineAddress = address(4);
    /// @dev TODO: We need a USDz price feed
    address internal usdcUsdPriceFeed;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    AccountNFT internal perpsAccountToken;
    USDToken internal usdToken;
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        // chainlinkForwarder = vm.envAddress("CHAINLINK_FORWARDER");
        // chainlinkVerifier = vm.envAddress("CHAINLINK_VERIFIER");
        perpsAccountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC", deployer);
        usdToken = USDToken(vm.envAddress("USDZ"));
        usdcUsdPriceFeed = vm.envAddress("USDC_USD_PRICE_FEED");

        address[] memory modules = deployModules();
        bytes4[][] memory modulesSelectors = getModulesSelectors();

        IDiamond.FacetCut[] memory facetCuts = getFacetCuts(modules, modulesSelectors, IDiamond.FacetCutAction.Add);
        address[] memory initializables = getInitializables(modules);
        bytes[] memory initializePayloads = getInitializePayloads(
            deployer,
            address(perpsAccountToken),
            mockRewardDistributorAddress,
            address(usdToken),
            mockLiquidityEngineAddress
        );

        IDiamond.InitParams memory initParams = IDiamond.InitParams({
            baseFacets: facetCuts,
            initializables: initializables,
            initializePayloads: initializePayloads
        });

        perpsEngine = IPerpsEngine(address(new PerpsEngine(initParams)));

        // TODO: need to update this once we properly configure the CL Data Streams fee payment tokens
        payable(address(perpsEngine)).transfer(0.1 ether);

        configureContracts();
        logContracts(modules);
    }

    function configureContracts() internal {
        perpsAccountToken.transferOwnership(address(perpsEngine));

        // TODO: add margin collateral configuration paremeters to a JSON file and use ffi
        perpsEngine.configureMarginCollateral(address(usdToken), type(uint128).max, 100e18, usdcUsdPriceFeed);
    }

    function logContracts(address[] memory modules) internal view {
        for (uint256 i = 0; i < modules.length; i++) {
            console.log("Module: ");
            console.log(modules[i]);
        }

        console.log("Perps Account NFT: ");
        console.log(address(perpsAccountToken));

        console.log("Perps Engine Proxy: ");
        console.log(address(perpsEngine));
    }
}
