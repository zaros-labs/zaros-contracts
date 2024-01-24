// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { AccountNFT } from "@zaros/account-nft/AccountNFT.sol";
import { IDiamond } from "@zaros/diamonds/interfaces/IDiamond.sol";
import { Diamond } from "@zaros/diamonds/Diamond.sol";
import { DiamondCutModule } from "@zaros/diamonds/modules/DiamondCutModule.sol";
import { DiamondLoupeModule } from "@zaros/diamonds/modules/DiamondLoupeModule.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { GlobalConfigurationModule } from "@zaros/markets/perps/modules/GlobalConfigurationModule.sol";
import { OrderModule } from "@zaros/markets/perps/modules/OrderModule.sol";
import { PerpMarketModule } from "@zaros/markets/perps/modules/PerpMarketModule.sol";
import { PerpsAccountModule } from "@zaros/markets/perps/modules/PerpsAccountModule.sol";
import { SettlementModule } from "@zaros/markets/perps/modules/SettlementModule.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { USDToken } from "@zaros/usd/USDToken.sol";
import { BaseScript } from "./Base.s.sol";

// Forge dependencies
import "forge-std/console.sol";

contract DeployAlphaPerps is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal chainlinkForwarder;
    address internal chainlinkVerifier;
    address internal mockRewardDistributorAddress = address(3);
    address internal mockZarosAddress = address(4);
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

        IDiamond.FacetCut[] memory facetCuts = getFacetCuts(modules, modulesSelectors);
        address[] memory initializables = new address[](1);
        address globalConfigurationModule = modules[0];
        initializables[0] = globalConfigurationModule;

        bytes memory initializeData = abi.encodeWithSelector(
            GlobalConfigurationModule.initialize.selector,
            deployer,
            address(perpsAccountToken),
            mockRewardDistributorAddress,
            address(usdToken),
            mockZarosAddress
        );

        bytes[] memory initializePayloads = new bytes[](1);
        initializePayloads[0] = initializeData;

        IDiamond.InitParams memory initParams = IDiamond.InitParams({
            baseFacets: facetCuts,
            initializables: initializables,
            initializePayloads: initializePayloads
        });

        perpsEngine = IPerpsEngine(address(new Diamond(initParams)));

        // TODO: need to update this once we properly configure the CL Data Streams fee payment tokens
        payable(address(perpsEngine)).transfer(1 ether);

        configureContracts();
        logContracts(modules);
    }

    function deployModules() internal returns (address[] memory modules) {
        address globalConfigurationModule = address(new GlobalConfigurationModule());
        address orderModule = address(new OrderModule());
        address perpMarketModule = address(new PerpMarketModule());
        address perpsAccountModule = address(new PerpsAccountModule());
        address settlementModule = address(new SettlementModule());

        modules[0] = globalConfigurationModule;
        modules[1] = orderModule;
        modules[2] = perpMarketModule;
        modules[3] = perpsAccountModule;
        modules[4] = settlementModule;
    }

    function getModulesSelectors() internal pure returns (bytes4[][]) {
        bytes4[][] memory selectors = new bytes4[][](7)();

        bytes4[] memory diamondCutModuleSelectors = new bytes4[](1);

        diamondCutModuleSelectors[0] = DiamondCutModule.updateModules.selector;

        bytes4[] memory diamondLoupeModuleSelectors = new bytes4[](6);

        diamondLoupeModuleSelectors[0] = DiamondLoupeModule.facets.selector;
        diamondLoupeModuleSelectors[1] = DiamondLoupeModule.facetFunctionSelectors.selector;
        diamondLoupeModuleSelectors[3] = DiamondLoupeModule.facetAddresses.selector;
        diamondLoupeModuleSelectors[2] = DiamondLoupeModule.facetAddress.selector;
        diamondLoupeModuleSelectors[4] = DiamondLoupeModule.facetSelectors.selector;

        bytes4[] memory globalConfigurationModuleSelectors = new bytes4[](9);

        globalConfigurationModuleSelectors[0] =
            GlobalConfigurationModule.getDepositCapForMarginCollateralConfiguration.selector;
        globalConfigurationModuleSelectors[1] = GlobalConfigurationModule.setPerpsAccountToken.selector;
        globalConfigurationModuleSelectors[2] = GlobalConfigurationModule.setLiquidityEngine.selector;
        globalConfigurationModuleSelectors[3] = GlobalConfigurationModule.configureMarginCollateral.selector;
        globalConfigurationModuleSelectors[4] = GlobalConfigurationModule.configureCollateralPriority.selector;
        globalConfigurationModuleSelectors[5] = GlobalConfigurationModule.removeCollateralFromPriorityList.selector;
        globalConfigurationModuleSelectors[6] = GlobalConfigurationModule.configureSystemParameters.selector;
        globalConfigurationModuleSelectors[7] = GlobalConfigurationModule.createPerpMarket.selector;
        globalConfigurationModuleSelectors[8] = GlobalConfigurationModule.upatePerpMarketStatus.selector;

        bytes4[] memory orderModuleSelectors = new bytes4[](7);

        orderModuleSelectors[0] = OrderModule.getConfiguredOrderFees.selector;
        orderModuleSelectors[1] = OrderModule.estimateOrderFee.selector;
        orderModuleSelectors[2] = OrderModule.getRequiredMarginForOrder.selector;
        orderModuleSelectors[3] = OrderModule.getActiveMarketOrder.selector;
        orderModuleSelectors[4] = OrderModule.createMarketOrder.selector;
        orderModuleSelectors[5] = OrderModule.dispatchCustomSettlementRequest.selector;
        orderModuleSelectors[6] = OrderModule.cancelMarketOrder.selector;

        bytes4[] memory perpMarketModuleSelectors = new bytes4[](11);

        perpMarketModuleSelectors[0] = PerpMarketModule.name.selector;
        perpMarketModuleSelectors[1] = PerpMarketModule.symbol.selector;
        perpMarketModuleSelectors[2] = PerpMarketModule.getMaxOpenInterest.selector;
        perpMarketModuleSelectors[3] = PerpMarketModule.getSkew.selector;
        perpMarketModuleSelectors[4] = PerpMarketModule.getOpenInterest.selector;
        perpMarketModuleSelectors[5] = PerpMarketModule.getMarkPrice.selector;
        perpMarketModuleSelectors[6] = PerpMarketModule.getSettlementConfiguration.selector;
        perpMarketModuleSelectors[7] = PerpMarketModule.getFundingRate.selector;
        perpMarketModuleSelectors[8] = PerpMarketModule.getFundingVelocity.selector;
        perpMarketModuleSelectors[9] = PerpMarketModule.getAccountLeverage.selector;
        perpMarketModuleSelectors[10] = PerpMarketModule.getMarketData.selector;

        bytes4[] memory perpsAccountModuleSelectors = new bytes4[](11);

        perpsAccountModuleSelectors[0] = PerpsAccountModule.getPerpsAccountToken.selector;
        perpsAccountModuleSelectors[1] = PerpsAccountModule.getAccountMarginCollateralBalance.selector;
        perpsAccountModuleSelectors[2] = PerpsAccountModule.getAccountEquityUsd.selector;
        perpsAccountModuleSelectors[3] = PerpsAccountModule.getAccountMarginBreakdown.selector;
        perpsAccountModuleSelectors[4] = PerpsAccountModule.getAccountTotalUnrealizedPnl.selector;
        perpsAccountModuleSelectors[5] = PerpsAccountModule.getOpenPositionData.selector;
        perpsAccountModuleSelectors[6] = PerpsAccountModule.createPerpsAccount.selector;
        perpsAccountModuleSelectors[7] = PerpsAccountModule.createPerpsAccountAndMulticall.selector;
        perpsAccountModuleSelectors[8] = PerpsAccountModule.depositMargin.selector;
        perpsAccountModuleSelectors[9] = PerpsAccountModule.withdrawMargin.selector;
        perpsAccountModuleSelectors[10] = PerpsAccountModule.notifyAccountTransfer.selector;

        bytes4[] memory settlementModuleSelectors = new bytes4[](2);

        settlementModuleSelectors[0] = SettlementModule.settleMarketOrder.selector;
        settlementModuleSelectors[1] = SettlementModule.settleCustomTriggers.selector;

        selectors[0] = globalConfigurationModuleSelectors;
        selectors[1] = orderModuleSelectors;
        selectors[2] = perpMarketModuleSelectors;
        selectors[3] = perpsAccountModuleSelectors;
        selectors[4] = settlementModuleSelectors;

        return selectors;
    }

    function getFacetCuts(
        address[] memory modules,
        bytes4[][] memory modulesSelectors
    )
        internal
        pure
        returns (IDiamond.FacetCut[] memory facetCuts)
    {
        for (uint256 i = 0; i < modules.length; i++) {
            bytes4[] memory selectors = modulesSelectors[i];

            facetCuts[i] =
                IDiamond.FacetCut({ facet: modules[i], action: IDiamond.FacetCutAction.Add, selectors: selectors });
        }
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
