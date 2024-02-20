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

contract DeployAlphaPerpsEngine is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal chainlinkForwarder;
    address internal chainlinkVerifier;
    address internal mockRewardDistributorAddress = address(3);
    address internal mockLiquidityEngineAddress = address(4);
    /// @dev TODO: We need a USDz price feed
    address internal usdcUsdPriceFeed;
    uint256 internal upkeepInitialLinkFunding;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    AccountNFT internal perpsAccountToken;
    address internal usdToken;
    address internal link;
    address internal automationRegistrar;
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        perpsAccountToken = new AccountNFT("Zaros Trading Accounts", "ZRS-TRADE-ACC", deployer);
        console.log("Perps Account NFT: ", address(perpsAccountToken));
        // usdToken = USDToken(vm.envAddress("USDZ"));
        usdToken = vm.envAddress("USDZ");
        link = vm.envAddress("LINK");
        automationRegistrar = vm.envAddress("CHAINLINK_AUTOMATION_REGISTRAR");
        usdcUsdPriceFeed = vm.envAddress("USDC_USD_PRICE_FEED");
        upkeepInitialLinkFunding = vm.envUint("UPKEEP_INITIAL_LINK_FUNDING");

        address[] memory modules = deployModules();
        bytes4[][] memory modulesSelectors = getModulesSelectors();

        IDiamond.FacetCut[] memory facetCuts = getFacetCuts(modules, modulesSelectors, IDiamond.FacetCutAction.Add);
        address[] memory initializables = getInitializables(modules);
        bytes[] memory initializePayloads = getInitializePayloads(
            deployer, address(perpsAccountToken), mockRewardDistributorAddress, usdToken, mockLiquidityEngineAddress
        );

        IDiamond.InitParams memory initParams = IDiamond.InitParams({
            baseFacets: facetCuts,
            initializables: initializables,
            initializePayloads: initializePayloads
        });

        perpsEngine = IPerpsEngine(address(new PerpsEngine(initParams)));
        console.log("Perps Engine Proxy: ", address(perpsEngine));

        // TODO: need to update this once we properly configure the CL Data Streams fee payment tokens
        payable(address(perpsEngine)).transfer(0.1 ether);

        configureContracts();
    }

    function configureContracts() internal {
        perpsAccountToken.transferOwnership(address(perpsEngine));

        // TODO: add missing configurations

        perpsEngine.setPerpsAccountToken(address(perpsAccountToken));

        perpsEngine.configureSystemParameters(
            MAX_POSITIONS_PER_ACCOUNT, MARKET_ORDER_MAX_LIFETIME, MIN_TRADE_SIZE_USD, LIQUIDATION_FEE_USD
        );

        address[] memory collateralLiquidationPriority = new address[](1);
        collateralLiquidationPriority[0] = address(usdToken);

        perpsEngine.configureCollateralPriority(collateralLiquidationPriority);

        // TODO: add margin collateral configuration paremeters to a JSON file and use ffi
        perpsEngine.configureMarginCollateral(address(usdToken), type(uint128).max, 1e18, usdcUsdPriceFeed);

        address liquidationUpkeep = address(new LiquidationUpkeep());

        console.log("Liquidation Upkeep: ", liquidationUpkeep);
        // AutomationHelpers.registerLiquidationUpkeep({
        //     name: PERPS_LIQUIDATION_UPKEEP_NAME,
        //     liquidationUpkeep: liquidationUpkeep,
        //     link: link,
        //     registrar: automationRegistrar,
        //     adminAddress: EDAO_ADDRESS,
        //     linkAmount: upkeepInitialLinkFunding
        // });

        address[] memory liquidators = new address[](1);
        bool[] memory liquidatorStatus = new bool[](1);

        liquidators[0] = liquidationUpkeep;
        liquidatorStatus[0] = true;

        perpsEngine.configureLiquidators(liquidators, liquidatorStatus);

        LimitedMintingERC20(address(usdToken)).transferOwnership(address(perpsEngine));
    }
}
