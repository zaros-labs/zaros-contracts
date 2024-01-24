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

// Open Zeppelin Upgradeable dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Forge dependencies
import "forge-std/console.sol";

contract DeployAlphaPerps is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal mockChainlinkForwarder = address(1);
    address internal mockChainlinkVerifier = address(2);
    address internal mockPerpsAccountTokenAddress = address(3);
    address internal mockRewardDistributorAddress = address(4);
    address internal mockZarosAddress = address(5);

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    USDToken internal usdToken;
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        usdToken = USDToken(vm.envAddress("USDZ"));

        address[] memory modules = deployModules();
        bytes4[][] memory modulesSelectors = getModulesSelectors();
        address[] memory initializables = new address[]();
        bytes[] memory initializePayloads = new bytes[]();

        IDiamond.FacetCut[] memory facetCuts = getFacetCuts(modules, modulesSelectors);

        perpsEngine = PerpsEngine(payable(vm.envAddress("PERPS_ENGINE")));
        perpsEngine.upgradeToAndCall(address(perpsEngineImplementation), bytes(""));

        logContracts();
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
        bytes4[][] memory selectors = new bytes4[][](5)();

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

    function logContracts() internal view {
        console.log("New Perps Engine Implementation: ");
        console.log(address(perpsEngineImplementation));

        console.log("Perps Engine Proxy: ");
        console.log(address(perpsEngine));
    }
}
