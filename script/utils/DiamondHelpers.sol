// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
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

function deployModules() returns (address[] memory modules) {
    address diamondCutModule = address(new DiamondCutModule());
    address diamondLoupeModule = address(new DiamondLoupeModule());
    address globalConfigurationModule = address(new GlobalConfigurationModule());
    address orderModule = address(new OrderModule());
    address perpMarketModule = address(new PerpMarketModule());
    address perpsAccountModule = address(new PerpsAccountModule());
    address settlementModule = address(new SettlementModule());

    modules[0] = diamondCutModule;
    modules[1] = diamondLoupeModule;
    modules[2] = globalConfigurationModule;
    modules[3] = orderModule;
    modules[4] = perpMarketModule;
    modules[5] = perpsAccountModule;
    modules[6] = settlementModule;
}

function getModulesSelectors() pure returns (bytes4[][] memory selectors) {
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
    globalConfigurationModuleSelectors[8] = GlobalConfigurationModule.updatePerpMarketStatus.selector;

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
}

function getFacetCuts(
    address[] memory modules,
    bytes4[][] memory modulesSelectors
)
    pure
    returns (IDiamond.FacetCut[] memory facetCuts)
{
    for (uint256 i = 0; i < modules.length; i++) {
        bytes4[] memory selectors = modulesSelectors[i];

        facetCuts[i] =
            IDiamond.FacetCut({ facet: modules[i], action: IDiamond.FacetCutAction.Add, selectors: selectors });
    }
}

function getInitializables(address[] memory modules) pure returns (address[] memory initializables) {
    initializables = new address[](2);

    address diamondCutModule = modules[0];
    address globalConfigurationModule = modules[2];

    initializables[0] = diamondCutModule;
    initializables[1] = globalConfigurationModule;
}

function getInitializePayloads(
    address deployer,
    address perpsAccountToken,
    address rewardDistributor,
    address usdToken,
    address zaros
)
    pure
    returns (bytes[] memory initializePayloads)
{
    bytes memory diamondCutInitializeData = abi.encodeWithSelector(DiamondCutModule.initialize.selector, deployer);
    bytes memory perpsInitializeData = abi.encodeWithSelector(
        GlobalConfigurationModule.initialize.selector, perpsAccountToken, rewardDistributor, usdToken, zaros
    );

    initializePayloads = new bytes[](2);

    initializePayloads[0] = diamondCutInitializeData;
    initializePayloads[1] = perpsInitializeData;
}
