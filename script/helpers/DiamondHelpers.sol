// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IDiamond } from "@zaros/diamonds/interfaces/IDiamond.sol";
import { DiamondCutModule } from "@zaros/diamonds/modules/DiamondCutModule.sol";
import { DiamondLoupeModule } from "@zaros/diamonds/modules/DiamondLoupeModule.sol";
import { GlobalConfigurationModule } from "@zaros/markets/perps/modules/GlobalConfigurationModule.sol";
import { LiquidationModule } from "@zaros/markets/perps/modules/LiquidationModule.sol";
import { OrderModule } from "@zaros/markets/perps/modules/OrderModule.sol";
import { PerpMarketModule } from "@zaros/markets/perps/modules/PerpMarketModule.sol";
import { PerpsAccountModule } from "@zaros/markets/perps/modules/PerpsAccountModule.sol";
import { SettlementModule } from "@zaros/markets/perps/modules/SettlementModule.sol";
import { PerpsAccountModuleTestnet } from "../../testnet/modules/PerpsAccountModuleTestnet.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

function deployModules(bool isTestnet) returns (address[] memory) {
    address[] memory modules = new address[](8);

    address diamondCutModule = address(new DiamondCutModule());
    console.log("DiamondCutModule: ", diamondCutModule);

    address diamondLoupeModule = address(new DiamondLoupeModule());
    console.log("DiamondLoupeModule: ", diamondLoupeModule);

    address globalConfigurationModule = address(new GlobalConfigurationModule());
    console.log("GlobalConfigurationModule: ", globalConfigurationModule);

    address liquidationModule = address(new LiquidationModule());
    console.log("LiquidationModule: ", liquidationModule);

    address orderModule = address(new OrderModule());
    console.log("OrderModule: ", orderModule);

    address perpMarketModule = address(new PerpMarketModule());
    console.log("PerpMarketModule: ", perpMarketModule);

    address perpsAccountModule;
    if (isTestnet) {
        perpsAccountModule = address(new PerpsAccountModuleTestnet());
    } else {
        perpsAccountModule = address(new PerpsAccountModule());
    }
    console.log("PerpsAccountModule: ", perpsAccountModule);

    address settlementModule = address(new SettlementModule());
    console.log("SettlementModule: ", settlementModule);

    modules[0] = diamondCutModule;
    modules[1] = diamondLoupeModule;
    modules[2] = globalConfigurationModule;
    modules[3] = liquidationModule;
    modules[4] = orderModule;
    modules[5] = perpMarketModule;
    modules[6] = perpsAccountModule;
    modules[7] = settlementModule;

    return modules;
}

function getModulesSelectors() pure returns (bytes4[][] memory) {
    bytes4[][] memory selectors = new bytes4[][](8);

    bytes4[] memory diamondCutModuleSelectors = new bytes4[](1);

    diamondCutModuleSelectors[0] = DiamondCutModule.updateModules.selector;

    bytes4[] memory diamondLoupeModuleSelectors = new bytes4[](5);

    diamondLoupeModuleSelectors[0] = DiamondLoupeModule.facets.selector;
    diamondLoupeModuleSelectors[1] = DiamondLoupeModule.facetFunctionSelectors.selector;
    diamondLoupeModuleSelectors[3] = DiamondLoupeModule.facetAddresses.selector;
    diamondLoupeModuleSelectors[2] = DiamondLoupeModule.facetAddress.selector;
    diamondLoupeModuleSelectors[4] = DiamondLoupeModule.facetSelectors.selector;

    bytes4[] memory globalConfigurationModuleSelectors = new bytes4[](12);

    globalConfigurationModuleSelectors[0] = GlobalConfigurationModule.getAccountsWithActivePositions.selector;
    globalConfigurationModuleSelectors[1] =
        GlobalConfigurationModule.getDepositCapForMarginCollateralConfiguration.selector;
    globalConfigurationModuleSelectors[2] = GlobalConfigurationModule.setPerpsAccountToken.selector;
    globalConfigurationModuleSelectors[3] = GlobalConfigurationModule.setLiquidityEngine.selector;
    globalConfigurationModuleSelectors[4] = GlobalConfigurationModule.configureCollateralPriority.selector;
    globalConfigurationModuleSelectors[5] = GlobalConfigurationModule.configureLiquidators.selector;
    globalConfigurationModuleSelectors[6] = GlobalConfigurationModule.configureMarginCollateral.selector;
    globalConfigurationModuleSelectors[7] = GlobalConfigurationModule.removeCollateralFromPriorityList.selector;
    globalConfigurationModuleSelectors[8] = GlobalConfigurationModule.configureSystemParameters.selector;
    globalConfigurationModuleSelectors[9] = GlobalConfigurationModule.createPerpMarket.selector;
    globalConfigurationModuleSelectors[10] = GlobalConfigurationModule.updatePerpMarketConfiguration.selector;
    globalConfigurationModuleSelectors[11] = GlobalConfigurationModule.updatePerpMarketStatus.selector;

    bytes4[] memory liquidationModuleSelectors = new bytes4[](2);

    liquidationModuleSelectors[0] = LiquidationModule.checkLiquidatableAccounts.selector;
    liquidationModuleSelectors[1] = LiquidationModule.liquidateAccounts.selector;

    bytes4[] memory orderModuleSelectors = new bytes4[](7);

    orderModuleSelectors[0] = OrderModule.getConfiguredOrderFees.selector;
    orderModuleSelectors[1] = OrderModule.simulateSettlement.selector;
    orderModuleSelectors[2] = OrderModule.getMarginRequirementsForTrade.selector;
    orderModuleSelectors[3] = OrderModule.getActiveMarketOrder.selector;
    orderModuleSelectors[4] = OrderModule.createMarketOrder.selector;
    orderModuleSelectors[5] = OrderModule.dispatchCustomOrder.selector;
    orderModuleSelectors[6] = OrderModule.cancelMarketOrder.selector;

    bytes4[] memory perpMarketModuleSelectors = new bytes4[](10);

    perpMarketModuleSelectors[0] = PerpMarketModule.name.selector;
    perpMarketModuleSelectors[1] = PerpMarketModule.symbol.selector;
    perpMarketModuleSelectors[2] = PerpMarketModule.getMaxOpenInterest.selector;
    perpMarketModuleSelectors[3] = PerpMarketModule.getSkew.selector;
    perpMarketModuleSelectors[4] = PerpMarketModule.getOpenInterest.selector;
    perpMarketModuleSelectors[5] = PerpMarketModule.getMarkPrice.selector;
    perpMarketModuleSelectors[6] = PerpMarketModule.getSettlementConfiguration.selector;
    perpMarketModuleSelectors[7] = PerpMarketModule.getFundingRate.selector;
    perpMarketModuleSelectors[8] = PerpMarketModule.getFundingVelocity.selector;
    perpMarketModuleSelectors[9] = PerpMarketModule.getMarketData.selector;

    bytes4[] memory perpsAccountModuleSelectors = new bytes4[](12);

    perpsAccountModuleSelectors[0] = PerpsAccountModule.getPerpsAccountToken.selector;
    perpsAccountModuleSelectors[1] = PerpsAccountModule.getAccountMarginCollateralBalance.selector;
    perpsAccountModuleSelectors[2] = PerpsAccountModule.getAccountEquityUsd.selector;
    perpsAccountModuleSelectors[3] = PerpsAccountModule.getAccountMarginBreakdown.selector;
    perpsAccountModuleSelectors[4] = PerpsAccountModule.getAccountTotalUnrealizedPnl.selector;
    perpsAccountModuleSelectors[5] = PerpsAccountModule.getAccountLeverage.selector;
    perpsAccountModuleSelectors[6] = PerpsAccountModule.getOpenPositionData.selector;
    perpsAccountModuleSelectors[7] = PerpsAccountModule.createPerpsAccount.selector;
    perpsAccountModuleSelectors[8] = PerpsAccountModule.createPerpsAccountAndMulticall.selector;
    perpsAccountModuleSelectors[9] = PerpsAccountModule.depositMargin.selector;
    perpsAccountModuleSelectors[10] = PerpsAccountModule.withdrawMargin.selector;
    perpsAccountModuleSelectors[11] = PerpsAccountModule.notifyAccountTransfer.selector;

    bytes4[] memory settlementModuleSelectors = new bytes4[](2);

    settlementModuleSelectors[0] = SettlementModule.settleMarketOrder.selector;
    settlementModuleSelectors[1] = SettlementModule.settleCustomOrders.selector;

    selectors[0] = diamondCutModuleSelectors;
    selectors[1] = diamondLoupeModuleSelectors;
    selectors[2] = globalConfigurationModuleSelectors;
    selectors[3] = liquidationModuleSelectors;
    selectors[4] = orderModuleSelectors;
    selectors[5] = perpMarketModuleSelectors;
    selectors[6] = perpsAccountModuleSelectors;
    selectors[7] = settlementModuleSelectors;

    return selectors;
}

function getFacetCuts(
    address[] memory modules,
    bytes4[][] memory modulesSelectors,
    IDiamond.FacetCutAction action
)
    pure
    returns (IDiamond.FacetCut[] memory)
{
    require(modules.length == modulesSelectors.length, "DiamondHelpers: modulesSelectors length mismatch");
    IDiamond.FacetCut[] memory facetCuts = new IDiamond.FacetCut[](modules.length);

    for (uint256 i = 0; i < modules.length; i++) {
        bytes4[] memory selectors = modulesSelectors[i];

        facetCuts[i] = IDiamond.FacetCut({ facet: modules[i], action: action, selectors: selectors });
    }

    return facetCuts;
}

function getInitializables(address[] memory modules, bool isTestnet) pure returns (address[] memory) {
    address[] memory initializables = new address[](3);

    address diamondCutModule = modules[0];
    address globalConfigurationModule = modules[2];

    initializables[0] = diamondCutModule;
    initializables[1] = globalConfigurationModule;

    if (isTestnet) {
        address perpsAccountModuleTestnet = modules[6];
        initializables[2] = perpsAccountModuleTestnet;
    }

    return initializables;
}

function getInitializePayloads(
    address deployer,
    address perpsAccountToken,
    address rewardDistributor,
    address usdToken,
    address zaros,
    address _accessKeyManager,
    bool isTestnet
)
    pure
    returns (bytes[] memory)
{
    bytes[] memory initializePayloads = new bytes[](2);

    bytes memory diamondCutInitializeData = abi.encodeWithSelector(DiamondCutModule.initialize.selector, deployer);
    bytes memory perpsInitializeData = abi.encodeWithSelector(
        GlobalConfigurationModule.initialize.selector, perpsAccountToken, rewardDistributor, usdToken, zaros
    );

    initializePayloads = new bytes[](3);

    initializePayloads[0] = diamondCutInitializeData;
    initializePayloads[1] = perpsInitializeData;

    if (isTestnet) {
        bytes memory perpsAccountTestnetData =
            abi.encodeWithSelector(PerpsAccountModuleTestnet.initialize.selector, _accessKeyManager);
        initializePayloads[2] = perpsAccountTestnetData;
    }

    return initializePayloads;
}
