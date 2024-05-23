// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { UpgradeBranch } from "@zaros/tree-proxy/branches/UpgradeBranch.sol";
import { LookupBranch } from "@zaros/tree-proxy/branches/LookupBranch.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { LiquidationBranch } from "@zaros/perpetuals/branches/LiquidationBranch.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { PerpMarketBranch } from "@zaros/perpetuals/branches/PerpMarketBranch.sol";
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";
import { SettlementBranch } from "@zaros/perpetuals/branches/SettlementBranch.sol";
import { GlobalConfigurationBranchTestnet } from "@zaros/testnet/branches/GlobalConfigurationBranchTestnet.sol";
import { TradingAccountBranchTestnet } from "@zaros/testnet/branches/TradingAccountBranchTestnet.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

function deployBranches(bool isTestnet) returns (address[] memory) {
    address[] memory branches = new address[](8);

    address upgradeBranch = address(new UpgradeBranch());
    console.log("UpgradeBranch: ", upgradeBranch);

    address lookupBranch = address(new LookupBranch());
    console.log("LookupBranch: ", lookupBranch);

    address liquidationBranch = address(new LiquidationBranch());
    console.log("LiquidationBranch: ", liquidationBranch);

    address orderBranch = address(new OrderBranch());
    console.log("OrderBranch: ", orderBranch);

    address perpMarketBranch = address(new PerpMarketBranch());
    console.log("PerpMarketBranch: ", perpMarketBranch);

    address settlementBranch = address(new SettlementBranch());
    console.log("SettlementBranch: ", settlementBranch);

    address globalConfigurationBranch;
    address tradingAccountBranch;
    if (isTestnet) {
        globalConfigurationBranch = address(new GlobalConfigurationBranchTestnet());
        tradingAccountBranch = address(new TradingAccountBranchTestnet());
    } else {
        globalConfigurationBranch = address(new GlobalConfigurationBranch());
        tradingAccountBranch = address(new TradingAccountBranch());
    }
    console.log("GlobalConfigurationBranch: ", globalConfigurationBranch);
    console.log("TradingAccountBranch: ", tradingAccountBranch);

    branches[0] = upgradeBranch;
    branches[1] = lookupBranch;
    branches[2] = globalConfigurationBranch;
    branches[3] = liquidationBranch;
    branches[4] = orderBranch;
    branches[5] = perpMarketBranch;
    branches[6] = tradingAccountBranch;
    branches[7] = settlementBranch;

    return branches;
}

function getBranchesSelectors(bool isTestnet) pure returns (bytes4[][] memory) {
    bytes4[][] memory selectors = new bytes4[][](8);

    bytes4[] memory upgradeBranchSelectors = new bytes4[](1);

    upgradeBranchSelectors[0] = UpgradeBranch.upgrade.selector;

    bytes4[] memory lookupBranchSelectors = new bytes4[](5);

    lookupBranchSelectors[0] = LookupBranch.branches.selector;
    lookupBranchSelectors[1] = LookupBranch.branchFunctionSelectors.selector;
    lookupBranchSelectors[3] = LookupBranch.branchAddresses.selector;
    lookupBranchSelectors[2] = LookupBranch.branchAddress.selector;
    lookupBranchSelectors[4] = LookupBranch.branchSelectors.selector;

    bytes4[] memory globalConfigurationBranchSelectors = new bytes4[](isTestnet ? 15 : 12);

    globalConfigurationBranchSelectors[0] = GlobalConfigurationBranch.getAccountsWithActivePositions.selector;
    globalConfigurationBranchSelectors[1] = GlobalConfigurationBranch.getMarginCollateralConfiguration.selector;
    globalConfigurationBranchSelectors[2] = GlobalConfigurationBranch.setTradingAccountToken.selector;
    globalConfigurationBranchSelectors[3] = GlobalConfigurationBranch.configureCollateralLiquidationPriority.selector;
    globalConfigurationBranchSelectors[4] = GlobalConfigurationBranch.configureLiquidators.selector;
    globalConfigurationBranchSelectors[5] = GlobalConfigurationBranch.configureMarginCollateral.selector;
    globalConfigurationBranchSelectors[6] = GlobalConfigurationBranch.removeCollateralFromLiquidationPriority.selector;
    globalConfigurationBranchSelectors[7] = GlobalConfigurationBranch.configureSystemParameters.selector;
    globalConfigurationBranchSelectors[8] = GlobalConfigurationBranch.createPerpMarket.selector;
    globalConfigurationBranchSelectors[9] = GlobalConfigurationBranch.updatePerpMarketConfiguration.selector;
    globalConfigurationBranchSelectors[10] = GlobalConfigurationBranch.updatePerpMarketStatus.selector;
    globalConfigurationBranchSelectors[11] = GlobalConfigurationBranch.updateSettlementConfiguration.selector;

    if (isTestnet) {
        globalConfigurationBranchSelectors[12] =
            GlobalConfigurationBranchTestnet.getCustomReferralCodeReferrer.selector;
        globalConfigurationBranchSelectors[13] = GlobalConfigurationBranchTestnet.setUserPoints.selector;
        globalConfigurationBranchSelectors[14] = GlobalConfigurationBranchTestnet.createCustomReferralCode.selector;
    }

    bytes4[] memory liquidationBranchSelectors = new bytes4[](2);

    liquidationBranchSelectors[0] = LiquidationBranch.checkLiquidatableAccounts.selector;
    liquidationBranchSelectors[1] = LiquidationBranch.liquidateAccounts.selector;

    bytes4[] memory orderBranchSelectors = new bytes4[](6);

    orderBranchSelectors[0] = OrderBranch.getConfiguredOrderFees.selector;
    orderBranchSelectors[1] = OrderBranch.simulateTrade.selector;
    orderBranchSelectors[2] = OrderBranch.getMarginRequirementForTrade.selector;
    orderBranchSelectors[3] = OrderBranch.getActiveMarketOrder.selector;
    orderBranchSelectors[4] = OrderBranch.createMarketOrder.selector;
    orderBranchSelectors[5] = OrderBranch.cancelMarketOrder.selector;

    bytes4[] memory perpMarketBranchSelectors = new bytes4[](11);

    perpMarketBranchSelectors[0] = PerpMarketBranch.getName.selector;
    perpMarketBranchSelectors[1] = PerpMarketBranch.getSymbol.selector;
    perpMarketBranchSelectors[2] = PerpMarketBranch.getMaxOpenInterest.selector;
    perpMarketBranchSelectors[3] = PerpMarketBranch.getMaxSkew.selector;
    perpMarketBranchSelectors[4] = PerpMarketBranch.getSkew.selector;
    perpMarketBranchSelectors[5] = PerpMarketBranch.getOpenInterest.selector;
    perpMarketBranchSelectors[6] = PerpMarketBranch.getMarkPrice.selector;
    perpMarketBranchSelectors[7] = PerpMarketBranch.getSettlementConfiguration.selector;
    perpMarketBranchSelectors[8] = PerpMarketBranch.getFundingRate.selector;
    perpMarketBranchSelectors[9] = PerpMarketBranch.getFundingVelocity.selector;
    perpMarketBranchSelectors[10] = PerpMarketBranch.getPerpMarketConfiguration.selector;

    bytes4[] memory tradingAccountBranchSelectors = new bytes4[](isTestnet ? 14 : 12);

    tradingAccountBranchSelectors[0] = TradingAccountBranch.getTradingAccountToken.selector;
    tradingAccountBranchSelectors[1] = TradingAccountBranch.getAccountMarginCollateralBalance.selector;
    tradingAccountBranchSelectors[2] = TradingAccountBranch.getAccountEquityUsd.selector;
    tradingAccountBranchSelectors[3] = TradingAccountBranch.getAccountMarginBreakdown.selector;
    tradingAccountBranchSelectors[4] = TradingAccountBranch.getAccountTotalUnrealizedPnl.selector;
    tradingAccountBranchSelectors[5] = TradingAccountBranch.getAccountLeverage.selector;
    tradingAccountBranchSelectors[6] = TradingAccountBranch.getPositionState.selector;
    tradingAccountBranchSelectors[7] = TradingAccountBranch.createTradingAccount.selector;
    tradingAccountBranchSelectors[8] = TradingAccountBranch.createTradingAccountAndMulticall.selector;
    tradingAccountBranchSelectors[9] = TradingAccountBranch.depositMargin.selector;
    tradingAccountBranchSelectors[10] = TradingAccountBranch.withdrawMargin.selector;
    tradingAccountBranchSelectors[11] = TradingAccountBranch.notifyAccountTransfer.selector;

    if (isTestnet) {
        tradingAccountBranchSelectors[7] = bytes4(keccak256("createTradingAccount(bytes,bool)"));
        tradingAccountBranchSelectors[8] = bytes4(keccak256("createTradingAccountAndMulticall(bytes[],bytes,bool)"));
        tradingAccountBranchSelectors[12] = TradingAccountBranchTestnet.isUserAccountCreated.selector;
        tradingAccountBranchSelectors[13] = TradingAccountBranchTestnet.getUserReferralData.selector;
    }

    bytes4[] memory settlementBranchSelectors = new bytes4[](2);

    settlementBranchSelectors[0] = SettlementBranch.fillMarketOrder.selector;
    settlementBranchSelectors[1] = SettlementBranch.fillCustomOrders.selector;

    selectors[0] = upgradeBranchSelectors;
    selectors[1] = lookupBranchSelectors;
    selectors[2] = globalConfigurationBranchSelectors;
    selectors[3] = liquidationBranchSelectors;
    selectors[4] = orderBranchSelectors;
    selectors[5] = perpMarketBranchSelectors;
    selectors[6] = tradingAccountBranchSelectors;
    selectors[7] = settlementBranchSelectors;

    return selectors;
}

function getBranchUpgrades(
    address[] memory branches,
    bytes4[][] memory branchesSelectors,
    RootProxy.BranchUpgradeAction action
)
    pure
    returns (RootProxy.BranchUpgrade[] memory)
{
    require(branches.length == branchesSelectors.length, "TreeProxyHelpers: branchesSelectors length mismatch");
    RootProxy.BranchUpgrade[] memory branchUpgrades = new RootProxy.BranchUpgrade[](branches.length);

    for (uint256 i = 0; i < branches.length; i++) {
        bytes4[] memory selectors = branchesSelectors[i];

        branchUpgrades[i] = RootProxy.BranchUpgrade({ branch: branches[i], action: action, selectors: selectors });
    }

    return branchUpgrades;
}

function getInitializables(address[] memory branches) pure returns (address[] memory) {
    address[] memory initializables = new address[](2);

    address upgradeBranch = branches[0];
    address globalConfigurationBranch = branches[2];

    initializables[0] = upgradeBranch;
    initializables[1] = globalConfigurationBranch;

    return initializables;
}

function getInitializePayloads(
    address deployer,
    address tradingAccountToken,
    address usdToken
)
    pure
    returns (bytes[] memory)
{
    bytes[] memory initializePayloads = new bytes[](2);

    bytes memory rootUpgradeInitializeData = abi.encodeWithSelector(UpgradeBranch.initialize.selector, deployer);
    bytes memory perpsEngineInitializeData =
        abi.encodeWithSelector(GlobalConfigurationBranch.initialize.selector, tradingAccountToken, usdToken);

    initializePayloads = new bytes[](2);

    initializePayloads[0] = rootUpgradeInitializeData;
    initializePayloads[1] = perpsEngineInitializeData;

    return initializePayloads;
}
