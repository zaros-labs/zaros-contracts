// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IRootProxy } from "@zaros/tree-proxy/interfaces/IRootProxy.sol";
import { UpgradeBranch } from "@zaros/tree-proxy/branches/UpgradeBranch.sol";
import { LookupBranch } from "@zaros/tree-proxy/branches/LookupBranch.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { LiquidationBranch } from "@zaros/perpetuals/branches/LiquidationBranch.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { PerpMarketBranch } from "@zaros/perpetuals/branches/PerpMarketBranch.sol";
import { PerpsAccountBranch } from "@zaros/perpetuals/branches/PerpsAccountBranch.sol";
import { SettlementBranch } from "@zaros/perpetuals/branches/SettlementBranch.sol";
import { GlobalConfigurationBranchTestnet } from "@zaros/testnet/branches/GlobalConfigurationBranchTestnet.sol";
import { PerpsAccountBranchTestnet } from "@zaros/testnet/branches/PerpsAccountBranchTestnet.sol";
import { SettlementBranchTestnet } from "@zaros/testnet/branches/SettlementBranchTestnet.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

function deployBranchs(bool isTestnet) returns (address[] memory) {
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

    address globalConfigurationBranch;
    address perpsAccountBranch;
    address settlementBranch;
    if (isTestnet) {
        globalConfigurationBranch = address(new GlobalConfigurationBranchTestnet());
        perpsAccountBranch = address(new PerpsAccountBranchTestnet());
        settlementBranch = address(new SettlementBranchTestnet());
    } else {
        globalConfigurationBranch = address(new GlobalConfigurationBranch());
        perpsAccountBranch = address(new PerpsAccountBranch());
        settlementBranch = address(new SettlementBranch());
    }
    console.log("GlobalConfigurationBranch: ", globalConfigurationBranch);
    console.log("PerpsAccountBranch: ", perpsAccountBranch);
    console.log("SettlementBranch: ", settlementBranch);

    branches[0] = upgradeBranch;
    branches[1] = lookupBranch;
    branches[2] = globalConfigurationBranch;
    branches[3] = liquidationBranch;
    branches[4] = orderBranch;
    branches[5] = perpMarketBranch;
    branches[6] = perpsAccountBranch;
    branches[7] = settlementBranch;

    return branches;
}

function getBranchsSelectors(bool isTestnet) pure returns (bytes4[][] memory) {
    bytes4[][] memory selectors = new bytes4[][](8);

    bytes4[] memory upgradeBranchSelectors = new bytes4[](1);

    upgradeBranchSelectors[0] = UpgradeBranch.upgrade.selector;

    bytes4[] memory lookupBranchSelectors = new bytes4[](5);

    lookupBranchSelectors[0] = LookupBranch.branches.selector;
    lookupBranchSelectors[1] = LookupBranch.branchFunctionSelectors.selector;
    lookupBranchSelectors[3] = LookupBranch.branchAddresses.selector;
    lookupBranchSelectors[2] = LookupBranch.branchAddress.selector;
    lookupBranchSelectors[4] = LookupBranch.branchSelectors.selector;

    bytes4[] memory globalConfigurationBranchSelectors = new bytes4[](isTestnet ? 15 : 13);

    globalConfigurationBranchSelectors[0] = GlobalConfigurationBranch.getAccountsWithActivePositions.selector;
    globalConfigurationBranchSelectors[1] = GlobalConfigurationBranch.getMarginCollateralConfiguration.selector;
    globalConfigurationBranchSelectors[2] = GlobalConfigurationBranch.setPerpsAccountToken.selector;
    globalConfigurationBranchSelectors[3] = GlobalConfigurationBranch.configureCollateralPriority.selector;
    globalConfigurationBranchSelectors[4] = GlobalConfigurationBranch.configureLiquidators.selector;
    globalConfigurationBranchSelectors[5] = GlobalConfigurationBranch.configureMarginCollateral.selector;
    globalConfigurationBranchSelectors[6] = GlobalConfigurationBranch.removeCollateralFromPriorityList.selector;
    globalConfigurationBranchSelectors[7] = GlobalConfigurationBranch.configureSystemParameters.selector;
    globalConfigurationBranchSelectors[8] = GlobalConfigurationBranch.createPerpMarket.selector;
    globalConfigurationBranchSelectors[9] = GlobalConfigurationBranch.updatePerpMarketConfiguration.selector;
    globalConfigurationBranchSelectors[10] = GlobalConfigurationBranch.updatePerpMarketStatus.selector;
    globalConfigurationBranchSelectors[11] = GlobalConfigurationBranch.updateSettlementConfiguration.selector;

    if (isTestnet) {
        globalConfigurationBranchSelectors[13] = GlobalConfigurationBranchTestnet.setUserPoints.selector;
        globalConfigurationBranchSelectors[14] = GlobalConfigurationBranchTestnet.createCustomReferralCode.selector;
    }

    bytes4[] memory liquidationBranchSelectors = new bytes4[](2);

    liquidationBranchSelectors[0] = LiquidationBranch.checkLiquidatableAccounts.selector;
    liquidationBranchSelectors[1] = LiquidationBranch.liquidateAccounts.selector;

    bytes4[] memory orderBranchSelectors = new bytes4[](7);

    orderBranchSelectors[0] = OrderBranch.getConfiguredOrderFees.selector;
    orderBranchSelectors[1] = OrderBranch.simulateTrade.selector;
    orderBranchSelectors[2] = OrderBranch.getMarginRequirementForTrade.selector;
    orderBranchSelectors[3] = OrderBranch.getActiveMarketOrder.selector;
    orderBranchSelectors[4] = OrderBranch.createMarketOrder.selector;
    orderBranchSelectors[5] = OrderBranch.createCustomOrder.selector;
    orderBranchSelectors[6] = OrderBranch.cancelMarketOrder.selector;

    bytes4[] memory perpMarketBranchSelectors = new bytes4[](10);

    perpMarketBranchSelectors[0] = PerpMarketBranch.name.selector;
    perpMarketBranchSelectors[1] = PerpMarketBranch.symbol.selector;
    perpMarketBranchSelectors[2] = PerpMarketBranch.getMaxOpenInterest.selector;
    perpMarketBranchSelectors[3] = PerpMarketBranch.getSkew.selector;
    perpMarketBranchSelectors[4] = PerpMarketBranch.getOpenInterest.selector;
    perpMarketBranchSelectors[5] = PerpMarketBranch.getMarkPrice.selector;
    perpMarketBranchSelectors[6] = PerpMarketBranch.getSettlementConfiguration.selector;
    perpMarketBranchSelectors[7] = PerpMarketBranch.getFundingRate.selector;
    perpMarketBranchSelectors[8] = PerpMarketBranch.getFundingVelocity.selector;
    perpMarketBranchSelectors[9] = PerpMarketBranch.getMarketData.selector;

    bytes4[] memory perpsAccountBranchSelectors = new bytes4[](isTestnet ? 16 : 12);

    perpsAccountBranchSelectors[0] = PerpsAccountBranch.getPerpsAccountToken.selector;
    perpsAccountBranchSelectors[1] = PerpsAccountBranch.getAccountMarginCollateralBalance.selector;
    perpsAccountBranchSelectors[2] = PerpsAccountBranch.getAccountEquityUsd.selector;
    perpsAccountBranchSelectors[3] = PerpsAccountBranch.getAccountMarginBreakdown.selector;
    perpsAccountBranchSelectors[4] = PerpsAccountBranch.getAccountTotalUnrealizedPnl.selector;
    perpsAccountBranchSelectors[5] = PerpsAccountBranch.getAccountLeverage.selector;
    perpsAccountBranchSelectors[6] = PerpsAccountBranch.getPositionState.selector;
    perpsAccountBranchSelectors[7] = PerpsAccountBranch.createPerpsAccount.selector;
    perpsAccountBranchSelectors[8] = PerpsAccountBranch.createPerpsAccountAndMulticall.selector;
    perpsAccountBranchSelectors[9] = PerpsAccountBranch.depositMargin.selector;
    perpsAccountBranchSelectors[10] = PerpsAccountBranch.withdrawMargin.selector;
    perpsAccountBranchSelectors[11] = PerpsAccountBranch.notifyAccountTransfer.selector;

    if (isTestnet) {
        perpsAccountBranchSelectors[7] = bytes4(keccak256("createPerpsAccount(bytes,bool)"));
        perpsAccountBranchSelectors[8] = bytes4(keccak256("createPerpsAccountAndMulticall(bytes[],bytes,bool)"));
        perpsAccountBranchSelectors[12] = PerpsAccountBranchTestnet.getAccessKeyManager.selector;
        perpsAccountBranchSelectors[13] = PerpsAccountBranchTestnet.isUserAccountCreated.selector;
        perpsAccountBranchSelectors[14] = PerpsAccountBranchTestnet.getPointsOfUser.selector;
        perpsAccountBranchSelectors[15] = PerpsAccountBranchTestnet.getUserReferralData.selector;
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
    selectors[6] = perpsAccountBranchSelectors;
    selectors[7] = settlementBranchSelectors;

    return selectors;
}

function getBranchUpgrades(
    address[] memory branches,
    bytes4[][] memory branchesSelectors,
    IRootProxy.BranchUpgradeAction action
)
    pure
    returns (IRootProxy.BranchUpgrade[] memory)
{
    require(branches.length == branchesSelectors.length, "DiamondHelpers: branchesSelectors length mismatch");
    IRootProxy.BranchUpgrade[] memory branchUpgrades = new IRootProxy.BranchUpgrade[](branches.length);

    for (uint256 i = 0; i < branches.length; i++) {
        bytes4[] memory selectors = branchesSelectors[i];

        branchUpgrades[i] = IRootProxy.BranchUpgrade({ branch: branches[i], action: action, selectors: selectors });
    }

    return branchUpgrades;
}

function getInitializables(address[] memory branches, bool isTestnet) pure returns (address[] memory) {
    address[] memory initializables = new address[](isTestnet ? 3 : 2);

    address upgradeBranch = branches[0];
    address globalConfigurationBranch = branches[2];

    initializables[0] = upgradeBranch;
    initializables[1] = globalConfigurationBranch;

    if (isTestnet) {
        address perpsAccountBranchTestnet = branches[6];
        initializables[2] = perpsAccountBranchTestnet;
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

    bytes memory rootUpgradeInitializeData = abi.encodeWithSelector(UpgradeBranch.initialize.selector, deployer);
    bytes memory perpsInitializeData = abi.encodeWithSelector(
        GlobalConfigurationBranch.initialize.selector, perpsAccountToken, rewardDistributor, usdToken, zaros
    );

    initializePayloads = new bytes[](isTestnet ? 3 : 2);

    initializePayloads[0] = rootUpgradeInitializeData;
    initializePayloads[1] = perpsInitializeData;

    if (isTestnet) {
        bytes memory perpsAccountTestnetData =
            abi.encodeWithSelector(PerpsAccountBranchTestnet.initialize.selector, _accessKeyManager);
        initializePayloads[2] = perpsAccountTestnetData;
    }

    return initializePayloads;
}
