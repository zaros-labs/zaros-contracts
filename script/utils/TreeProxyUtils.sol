// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { UpgradeBranch } from "@zaros/tree-proxy/branches/UpgradeBranch.sol";
import { LookupBranch } from "@zaros/tree-proxy/branches/LookupBranch.sol";
import { PerpsEngineConfigurationBranch } from "@zaros/perpetuals/branches/PerpsEngineConfigurationBranch.sol";
import { LiquidationBranch } from "@zaros/perpetuals/branches/LiquidationBranch.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { PerpMarketBranch } from "@zaros/perpetuals/branches/PerpMarketBranch.sol";
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";
import { SettlementBranch } from "@zaros/perpetuals/branches/SettlementBranch.sol";
import { TradingAccountBranchTestnet } from "testnet/branches/TradingAccountBranchTestnet.sol";
import { PerpsEngineConfigurationHarness } from "test/harnesses/perpetuals/leaves/PerpsEngineConfigurationHarness.sol";
import { MarginCollateralConfigurationHarness } from
    "test/harnesses/perpetuals/leaves/MarginCollateralConfigurationHarness.sol";
import { MarketConfigurationHarness } from "test/harnesses/perpetuals/leaves/MarketConfigurationHarness.sol";
import { MarketOrderHarness } from "test/harnesses/perpetuals/leaves/MarketOrderHarness.sol";
import { PerpMarketHarness } from "test/harnesses/perpetuals/leaves/PerpMarketHarness.sol";
import { PositionHarness } from "test/harnesses/perpetuals/leaves/PositionHarness.sol";
import { SettlementConfigurationHarness } from "test/harnesses/perpetuals/leaves/SettlementConfigurationHarness.sol";
import { TradingAccountHarness } from "test/harnesses/perpetuals/leaves/TradingAccountHarness.sol";
import { ReferralHarness } from "test/harnesses/perpetuals/leaves/ReferralHarness.sol";
import { CustomReferralConfigurationHarness } from
    "test/harnesses/perpetuals/leaves/CustomReferralConfigurationHarness.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";
import { VaultHarness } from "test/harnesses/market-making/leaves/VaultHarness.sol";
import { WithdrawalRequestHarness } from "test/harnesses/market-making/leaves/WithdrawalRequestHarness.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";
import { CollateralHarness } from "test/harnesses/market-making/leaves/CollateralHarness.sol";
import { DistributionHarness } from "test/harnesses/market-making/leaves/DistributionHarness.sol";
import { MarketDebtHarness } from "test/harnesses/market-making/leaves/MarketDebtHarness.sol";
import { MarketMakingEngineConfigurationHarness } from 
    "test/harnesses/market-making/leaves/MarketMakingEngineConfigurationHarness.sol";
import { SwapRouterHarness } from "test/harnesses/market-making/leaves/SwapRouterHarness.sol";
import { CollateralHarness } from "test/harnesses/market-making/leaves/CollateralHarness.sol";
import { FeeRecipientHarness } from "test/harnesses/market-making/leaves/FeeRecipientHarness.sol";

// Open Zeppelin Upgradeable dependencies
import { EIP712Upgradeable } from "@openzeppelin-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

// Perps Engine

function deployPerpsEngineBranches(bool isTestnet) returns (address[] memory) {
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

    address perpsEngineConfigurationBranch;
    address tradingAccountBranch;

    perpsEngineConfigurationBranch = address(new PerpsEngineConfigurationBranch());

    if (isTestnet) {
        tradingAccountBranch = address(new TradingAccountBranchTestnet());
    } else {
        tradingAccountBranch = address(new TradingAccountBranch());
    }
    console.log("PerpsEngineConfigurationBranch: ", perpsEngineConfigurationBranch);
    console.log("TradingAccountBranch: ", tradingAccountBranch);

    branches[0] = upgradeBranch;
    branches[1] = lookupBranch;
    branches[2] = perpsEngineConfigurationBranch;
    branches[3] = liquidationBranch;
    branches[4] = orderBranch;
    branches[5] = perpMarketBranch;
    branches[6] = tradingAccountBranch;
    branches[7] = settlementBranch;

    return branches;
}

function getPerpsEngineBranchesSelectors(bool isTestnet) pure returns (bytes4[][] memory) {
    bytes4[][] memory selectors = new bytes4[][](8);

    bytes4[] memory upgradeBranchSelectors = new bytes4[](1);

    upgradeBranchSelectors[0] = UpgradeBranch.upgrade.selector;

    bytes4[] memory lookupBranchSelectors = new bytes4[](4);

    lookupBranchSelectors[0] = LookupBranch.branches.selector;
    lookupBranchSelectors[1] = LookupBranch.branchFunctionSelectors.selector;
    lookupBranchSelectors[2] = LookupBranch.branchAddresses.selector;
    lookupBranchSelectors[3] = LookupBranch.branchAddress.selector;

    bytes4[] memory perpsEngineConfigurationBranchSelectors = new bytes4[](17);

    perpsEngineConfigurationBranchSelectors[0] =
        PerpsEngineConfigurationBranch.getAccountsWithActivePositions.selector;
    perpsEngineConfigurationBranchSelectors[1] =
        PerpsEngineConfigurationBranch.getMarginCollateralConfiguration.selector;
    perpsEngineConfigurationBranchSelectors[2] = PerpsEngineConfigurationBranch.setTradingAccountToken.selector;
    perpsEngineConfigurationBranchSelectors[3] =
        PerpsEngineConfigurationBranch.configureCollateralLiquidationPriority.selector;
    perpsEngineConfigurationBranchSelectors[4] = PerpsEngineConfigurationBranch.configureLiquidators.selector;
    perpsEngineConfigurationBranchSelectors[5] = PerpsEngineConfigurationBranch.configureMarginCollateral.selector;
    perpsEngineConfigurationBranchSelectors[6] =
        PerpsEngineConfigurationBranch.removeCollateralFromLiquidationPriority.selector;
    perpsEngineConfigurationBranchSelectors[7] = PerpsEngineConfigurationBranch.configureSystemParameters.selector;
    perpsEngineConfigurationBranchSelectors[8] = PerpsEngineConfigurationBranch.createPerpMarket.selector;
    perpsEngineConfigurationBranchSelectors[9] = PerpsEngineConfigurationBranch.updatePerpMarketConfiguration.selector;
    perpsEngineConfigurationBranchSelectors[10] = PerpsEngineConfigurationBranch.updatePerpMarketStatus.selector;
    perpsEngineConfigurationBranchSelectors[11] =
        PerpsEngineConfigurationBranch.updateSettlementConfiguration.selector;
    perpsEngineConfigurationBranchSelectors[12] = PerpsEngineConfigurationBranch.setUsdToken.selector;
    perpsEngineConfigurationBranchSelectors[13] =
        PerpsEngineConfigurationBranch.configureSequencerUptimeFeedByChainId.selector;
    perpsEngineConfigurationBranchSelectors[14] =
        PerpsEngineConfigurationBranch.getCustomReferralCodeReferrer.selector;
    perpsEngineConfigurationBranchSelectors[15] = PerpsEngineConfigurationBranch.createCustomReferralCode.selector;
    perpsEngineConfigurationBranchSelectors[16] =
        PerpsEngineConfigurationBranch.getSequencerUptimeFeedByChainId.selector;

    bytes4[] memory liquidationBranchSelectors = new bytes4[](2);

    liquidationBranchSelectors[0] = LiquidationBranch.checkLiquidatableAccounts.selector;
    liquidationBranchSelectors[1] = LiquidationBranch.liquidateAccounts.selector;

    bytes4[] memory orderBranchSelectors = new bytes4[](7);

    orderBranchSelectors[0] = OrderBranch.getConfiguredOrderFees.selector;
    orderBranchSelectors[1] = OrderBranch.simulateTrade.selector;
    orderBranchSelectors[2] = OrderBranch.getMarginRequirementForTrade.selector;
    orderBranchSelectors[3] = OrderBranch.getActiveMarketOrder.selector;
    orderBranchSelectors[4] = OrderBranch.createMarketOrder.selector;
    orderBranchSelectors[5] = OrderBranch.cancelAllOffchainOrders.selector;
    orderBranchSelectors[6] = OrderBranch.cancelMarketOrder.selector;

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

    bytes4[] memory tradingAccountBranchSelectors = new bytes4[](isTestnet ? 15 : 13);

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
    tradingAccountBranchSelectors[12] = TradingAccountBranch.getUserReferralData.selector;

    if (isTestnet) {
        tradingAccountBranchSelectors[13] = TradingAccountBranchTestnet.isUserAccountCreated.selector;
        tradingAccountBranchSelectors[14] = TradingAccountBranchTestnet.createTradingAccountWithSender.selector;
    }

    bytes4[] memory settlementBranchSelectors = new bytes4[](4);

    settlementBranchSelectors[0] = EIP712Upgradeable.eip712Domain.selector;
    settlementBranchSelectors[1] = SettlementBranch.DOMAIN_SEPARATOR.selector;
    settlementBranchSelectors[2] = SettlementBranch.fillMarketOrder.selector;
    settlementBranchSelectors[3] = SettlementBranch.fillOffchainOrders.selector;

    selectors[0] = upgradeBranchSelectors;
    selectors[1] = lookupBranchSelectors;
    selectors[2] = perpsEngineConfigurationBranchSelectors;
    selectors[3] = liquidationBranchSelectors;
    selectors[4] = orderBranchSelectors;
    selectors[5] = perpMarketBranchSelectors;
    selectors[6] = tradingAccountBranchSelectors;
    selectors[7] = settlementBranchSelectors;

    return selectors;
}

function getPerpsEngineInitializables(address[] memory branches) pure returns (address[] memory) {
    address[] memory initializables = new address[](2);

    address upgradeBranch = branches[0];
    address perpsEngineConfigurationBranch = branches[2];

    initializables[0] = upgradeBranch;
    initializables[1] = perpsEngineConfigurationBranch;

    return initializables;
}

function getPerpsEngineInitializePayloads(
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
        abi.encodeWithSelector(PerpsEngineConfigurationBranch.initialize.selector, tradingAccountToken, usdToken);

    initializePayloads = new bytes[](2);

    initializePayloads[0] = rootUpgradeInitializeData;
    initializePayloads[1] = perpsEngineInitializeData;

    return initializePayloads;
}

function deployPerpsEngineHarnesses(RootProxy.BranchUpgrade[] memory branchUpgrades)
    returns (RootProxy.BranchUpgrade[] memory)
{
    address[] memory harnesses = deployPerpsEngineAddressHarnesses();

    bytes4[][] memory harnessesSelectors = getPerpsEngineHarnessesSelectors();

    RootProxy.BranchUpgrade[] memory harnessesUpgrades =
        getBranchUpgrades(harnesses, harnessesSelectors, RootProxy.BranchUpgradeAction.Add);

    uint256 cachedBranchUpgradesLength = branchUpgrades.length;

    uint256 maxLength = cachedBranchUpgradesLength + harnessesUpgrades.length;

    RootProxy.BranchUpgrade[] memory brancheAndHarnessesUpgrades = new RootProxy.BranchUpgrade[](maxLength);

    for (uint256 i; i < maxLength; i++) {
        brancheAndHarnessesUpgrades[i] =
            i < cachedBranchUpgradesLength ? branchUpgrades[i] : harnessesUpgrades[i - cachedBranchUpgradesLength];
    }

    return brancheAndHarnessesUpgrades;
}

function deployPerpsEngineAddressHarnesses() returns (address[] memory) {
    address[] memory addressHarnesses = new address[](10);

    address perpsEngineConfigurationHarness = address(new PerpsEngineConfigurationHarness());
    console.log("PerpsEngineConfigurationHarness: ", perpsEngineConfigurationHarness);

    address marginCollateralConfigurationHarness = address(new MarginCollateralConfigurationHarness());
    console.log("MarginCollateralConfigurationHarness: ", marginCollateralConfigurationHarness);

    address marketConfigurationHarness = address(new MarketConfigurationHarness());
    console.log("MarketConfigurationHarness: ", marketConfigurationHarness);

    address marketOrderHarness = address(new MarketOrderHarness());
    console.log("MarketOrderHarness: ", marketOrderHarness);

    address perpMarketHarness = address(new PerpMarketHarness());
    console.log("PerpMarketHarness: ", perpMarketHarness);

    address positionHarness = address(new PositionHarness());
    console.log("PositionHarness: ", positionHarness);

    address settlementConfigurationHarness = address(new SettlementConfigurationHarness());
    console.log("SettlementConfigurationHarness: ", settlementConfigurationHarness);

    address tradingAccountHarness = address(new TradingAccountHarness());
    console.log("TradingAccountHarness: ", tradingAccountHarness);

    addressHarnesses[0] = perpsEngineConfigurationHarness;
    address referralHarness = address(new ReferralHarness());
    console.log("ReferralHarness: ", referralHarness);

    address customReferralConfigurationHarness = address(new CustomReferralConfigurationHarness());
    console.log("CustomReferralConfiguration: ", customReferralConfigurationHarness);

    addressHarnesses[0] = perpsEngineConfigurationHarness;
    addressHarnesses[1] = marginCollateralConfigurationHarness;
    addressHarnesses[2] = marketConfigurationHarness;
    addressHarnesses[3] = marketOrderHarness;
    addressHarnesses[4] = perpMarketHarness;
    addressHarnesses[5] = positionHarness;
    addressHarnesses[6] = settlementConfigurationHarness;
    addressHarnesses[7] = tradingAccountHarness;
    addressHarnesses[8] = referralHarness;
    addressHarnesses[9] = customReferralConfigurationHarness;

    return addressHarnesses;
}

function getPerpsEngineHarnessesSelectors() pure returns (bytes4[][] memory) {
    bytes4[][] memory selectors = new bytes4[][](10);

    bytes4[] memory perpsEngineConfigurationHarnessSelectors = new bytes4[](13);
    perpsEngineConfigurationHarnessSelectors[0] =
        PerpsEngineConfigurationHarness.exposed_checkMarketIsEnabled.selector;
    perpsEngineConfigurationHarnessSelectors[1] = PerpsEngineConfigurationHarness.exposed_addMarket.selector;
    perpsEngineConfigurationHarnessSelectors[2] = PerpsEngineConfigurationHarness.exposed_removeMarket.selector;
    perpsEngineConfigurationHarnessSelectors[3] =
        PerpsEngineConfigurationHarness.exposed_configureCollateralLiquidationPriority.selector;
    perpsEngineConfigurationHarnessSelectors[4] =
        PerpsEngineConfigurationHarness.exposed_removeCollateralFromLiquidationPriority.selector;
    perpsEngineConfigurationHarnessSelectors[5] =
        PerpsEngineConfigurationHarness.workaround_getAccountIdWithActivePositions.selector;
    perpsEngineConfigurationHarnessSelectors[6] =
        PerpsEngineConfigurationHarness.workaround_getAccountsIdsWithActivePositionsLength.selector;
    perpsEngineConfigurationHarnessSelectors[7] =
        PerpsEngineConfigurationHarness.workaround_getTradingAccountToken.selector;
    perpsEngineConfigurationHarnessSelectors[8] = PerpsEngineConfigurationHarness.workaround_getUsdToken.selector;
    perpsEngineConfigurationHarnessSelectors[9] =
        PerpsEngineConfigurationHarness.workaround_getCollateralLiquidationPriority.selector;
    perpsEngineConfigurationHarnessSelectors[10] =
        PerpsEngineConfigurationHarness.workaround_getSequencerUptimeFeedByChainId.selector;
    perpsEngineConfigurationHarnessSelectors[11] =
        PerpsEngineConfigurationHarness.workaround_getMaxPositionsPerAccount.selector;
    perpsEngineConfigurationHarnessSelectors[12] =
        PerpsEngineConfigurationHarness.workaround_getLiquidationFeeUsdX18.selector;

    bytes4[] memory marginCollateralConfigurationHarnessSelectors = new bytes4[](6);
    marginCollateralConfigurationHarnessSelectors[0] =
        MarginCollateralConfigurationHarness.exposed_MarginCollateral_load.selector;
    marginCollateralConfigurationHarnessSelectors[1] =
        MarginCollateralConfigurationHarness.exposed_convertTokenAmountToUd60x18.selector;
    marginCollateralConfigurationHarnessSelectors[2] =
        MarginCollateralConfigurationHarness.exposed_convertUd60x18ToTokenAmount.selector;
    marginCollateralConfigurationHarnessSelectors[3] = MarginCollateralConfigurationHarness.exposed_getPrice.selector;
    marginCollateralConfigurationHarnessSelectors[4] = MarginCollateralConfigurationHarness.exposed_configure.selector;
    marginCollateralConfigurationHarnessSelectors[5] =
        MarginCollateralConfigurationHarness.workaround_getTotalDeposited.selector;

    bytes4[] memory marketConfigurationHarnessSelectors = new bytes4[](1);
    marketConfigurationHarnessSelectors[0] = MarketConfigurationHarness.exposed_update.selector;

    bytes4[] memory marketOrderHarnessSelectors = new bytes4[](5);
    marketOrderHarnessSelectors[0] = MarketOrderHarness.exposed_MarketOrder_load.selector;
    marketOrderHarnessSelectors[1] = MarketOrderHarness.exposed_MarketOrder_loadExisting.selector;
    marketOrderHarnessSelectors[2] = MarketOrderHarness.exposed_update.selector;
    marketOrderHarnessSelectors[3] = MarketOrderHarness.exposed_clear.selector;
    marketOrderHarnessSelectors[4] = MarketOrderHarness.exposed_checkPendingOrder.selector;

    bytes4[] memory perpMarketHarnessSelectors = new bytes4[](14);
    perpMarketHarnessSelectors[0] = PerpMarketHarness.exposed_PerpMarket_load.selector;
    perpMarketHarnessSelectors[1] = PerpMarketHarness.exposed_getIndexPrice.selector;
    perpMarketHarnessSelectors[2] = PerpMarketHarness.exposed_getMarkPrice.selector;
    perpMarketHarnessSelectors[3] = PerpMarketHarness.exposed_getCurrentFundingRate.selector;
    perpMarketHarnessSelectors[4] = PerpMarketHarness.exposed_getCurrentFundingVelocity.selector;
    perpMarketHarnessSelectors[5] = PerpMarketHarness.exposed_getOrderFeeUsd.selector;
    perpMarketHarnessSelectors[6] = PerpMarketHarness.exposed_getNextFundingFeePerUnit.selector;
    perpMarketHarnessSelectors[7] = PerpMarketHarness.exposed_getPendingFundingFeePerUnit.selector;
    perpMarketHarnessSelectors[8] = PerpMarketHarness.exposed_getProportionalElapsedSinceLastFunding.selector;
    perpMarketHarnessSelectors[9] = PerpMarketHarness.exposed_checkOpenInterestLimits.selector;
    perpMarketHarnessSelectors[10] = PerpMarketHarness.exposed_checkTradeSize.selector;
    perpMarketHarnessSelectors[11] = PerpMarketHarness.exposed_updateFunding.selector;
    perpMarketHarnessSelectors[12] = PerpMarketHarness.exposed_updateOpenInterest.selector;
    perpMarketHarnessSelectors[13] = PerpMarketHarness.exposed_create.selector;

    bytes4[] memory positionHarnessSelectors = new bytes4[](9);
    positionHarnessSelectors[0] = PositionHarness.exposed_Position_load.selector;
    positionHarnessSelectors[1] = PositionHarness.exposed_getState.selector;
    positionHarnessSelectors[2] = PositionHarness.exposed_update.selector;
    positionHarnessSelectors[3] = PositionHarness.exposed_clear.selector;
    positionHarnessSelectors[4] = PositionHarness.exposed_getAccruedFunding.selector;
    positionHarnessSelectors[5] = PositionHarness.exposed_getMarginRequirements.selector;
    positionHarnessSelectors[6] = PositionHarness.exposed_getNotionalValue.selector;
    positionHarnessSelectors[7] = PositionHarness.exposed_getUnrealizedPnl.selector;
    positionHarnessSelectors[8] = PositionHarness.exposed_isNotionalValueIncreasing.selector;

    bytes4[] memory settlementConfigurationHarnessSelectors = new bytes4[](6);
    settlementConfigurationHarnessSelectors[0] =
        SettlementConfigurationHarness.exposed_SettlementConfiguration_load.selector;
    settlementConfigurationHarnessSelectors[1] =
        SettlementConfigurationHarness.exposed_checkIsSettlementEnabled.selector;
    settlementConfigurationHarnessSelectors[2] =
        SettlementConfigurationHarness.exposed_requireDataStreamsReportIsVaid.selector;
    settlementConfigurationHarnessSelectors[3] = SettlementConfigurationHarness.exposed_update.selector;
    settlementConfigurationHarnessSelectors[4] = SettlementConfigurationHarness.exposed_verifyOffchainPrice.selector;
    settlementConfigurationHarnessSelectors[5] =
        SettlementConfigurationHarness.exposed_verifyDataStreamsReport.selector;

    bytes4[] memory tradingAccountHarnessSelectors = new bytes4[](24);
    tradingAccountHarnessSelectors[0] = TradingAccountHarness.exposed_TradingAccount_loadExisting.selector;
    tradingAccountHarnessSelectors[1] = TradingAccountHarness.exposed_loadExistingAccountAndVerifySender.selector;
    tradingAccountHarnessSelectors[2] = TradingAccountHarness.exposed_validatePositionsLimit.selector;
    tradingAccountHarnessSelectors[3] = TradingAccountHarness.exposed_validateMarginRequirements.selector;
    tradingAccountHarnessSelectors[4] = TradingAccountHarness.exposed_getMarginCollateralBalance.selector;
    tradingAccountHarnessSelectors[5] = TradingAccountHarness.exposed_getEquityUsd.selector;
    tradingAccountHarnessSelectors[6] = TradingAccountHarness.exposed_getMarginBalanceUsd.selector;
    tradingAccountHarnessSelectors[7] =
        TradingAccountHarness.exposed_getAccountMarginRequirementUsdAndUnrealizedPnlUsd.selector;
    tradingAccountHarnessSelectors[8] = TradingAccountHarness.exposed_getAccontUnrealizedPnlUsd.selector;
    tradingAccountHarnessSelectors[9] = TradingAccountHarness.exposed_verifySender.selector;
    tradingAccountHarnessSelectors[10] = TradingAccountHarness.exposed_isLiquidatable.selector;
    tradingAccountHarnessSelectors[11] = TradingAccountHarness.exposed_create.selector;
    tradingAccountHarnessSelectors[12] = TradingAccountHarness.exposed_deposit.selector;
    tradingAccountHarnessSelectors[13] = TradingAccountHarness.exposed_withdraw.selector;
    tradingAccountHarnessSelectors[14] = TradingAccountHarness.exposed_withdrawMarginUsd.selector;
    tradingAccountHarnessSelectors[15] = TradingAccountHarness.exposed_deductAccountMargin.selector;
    tradingAccountHarnessSelectors[16] = TradingAccountHarness.exposed_updateActiveMarkets.selector;
    tradingAccountHarnessSelectors[17] = TradingAccountHarness.exposed_isMarketWithActivePosition.selector;
    tradingAccountHarnessSelectors[18] = TradingAccountHarness.workaround_getActiveMarketId.selector;
    tradingAccountHarnessSelectors[19] = TradingAccountHarness.workaround_getActiveMarketsIdsLength.selector;
    tradingAccountHarnessSelectors[20] = TradingAccountHarness.workaround_getNonce.selector;
    tradingAccountHarnessSelectors[21] = TradingAccountHarness.workaround_hasOffchainOrderBeenFilled.selector;
    tradingAccountHarnessSelectors[22] =
        TradingAccountHarness.workaround_getIfMarginCollateralBalanceX18ContainsTheCollateral.selector;
    tradingAccountHarnessSelectors[23] = TradingAccountHarness.workaround_getTradingAccountIdAndOwner.selector;

    bytes4[] memory referralHarnessSelectors = new bytes4[](2);
    referralHarnessSelectors[0] = ReferralHarness.exposed_Referral_load.selector;
    referralHarnessSelectors[1] = ReferralHarness.exposed_Referral_getReferrerAddress.selector;

    bytes4[] memory customReferralConfigurationHarnessSelectors = new bytes4[](1);
    customReferralConfigurationHarnessSelectors[0] =
        CustomReferralConfigurationHarness.exposed_CustomReferralConfiguration_load.selector;

    selectors[0] = perpsEngineConfigurationHarnessSelectors;
    selectors[1] = marginCollateralConfigurationHarnessSelectors;
    selectors[2] = marketConfigurationHarnessSelectors;
    selectors[3] = marketOrderHarnessSelectors;
    selectors[4] = perpMarketHarnessSelectors;
    selectors[5] = positionHarnessSelectors;
    selectors[6] = settlementConfigurationHarnessSelectors;
    selectors[7] = tradingAccountHarnessSelectors;
    selectors[8] = referralHarnessSelectors;
    selectors[9] = customReferralConfigurationHarnessSelectors;

    return selectors;
}

// Market Making Engine

function deployMarketMakingEngineBranches() returns (address[] memory) {
    address[] memory branches = new address[](3);

    address marketMakingEnginConfigBranch = address(new MarketMakingEngineConfigurationBranch());
    console.log("MarketMakingEnginConfigBranch: ", marketMakingEnginConfigBranch);

    address vaultRouterBranch = address(new VaultRouterBranch());
    console.log("VaultRouterBranch: ", vaultRouterBranch);

    address feeDistributionBranch = address(new FeeDistributionBranch());
    console.log("FeeDistributionBranch: ", feeDistributionBranch);

    branches[0] = marketMakingEnginConfigBranch;
    branches[1] = vaultRouterBranch;
    branches[2] = feeDistributionBranch;

    return branches;
}

function getMarketMakingEngineInitializables(address[] memory branches) pure returns (address[] memory) {
    address[] memory initializables = new address[](1);

    address marketMakingEnginConfigBranch = branches[0];

    initializables[0] = marketMakingEnginConfigBranch;

    return initializables;
}

function getMarketMakingEngineInitPayloads(
    address perpsEngine,
    address usdzToken,
    address owner
)
    pure
    returns (bytes[] memory)
{
    bytes[] memory initializePayloads = new bytes[](1);

    bytes memory marketMakingEngineInitializeData = abi.encodeWithSelector(
        MarketMakingEngineConfigurationBranch.initialize.selector, usdzToken, perpsEngine, owner
    );

    initializePayloads[0] = marketMakingEngineInitializeData;

    return initializePayloads;
}

function getMarketMakerBranchesSelectors() pure returns (bytes4[][] memory) {
    bytes4[][] memory selectors = new bytes4[][](3);

    bytes4[] memory marketMakingEngineConfigBranchSelectors = new bytes4[](9);
    marketMakingEngineConfigBranchSelectors[0] =
        MarketMakingEngineConfigurationBranch.configureSequencerUptimeFeed.selector;
    marketMakingEngineConfigBranchSelectors[1] =
        MarketMakingEngineConfigurationBranch.configureSystemParameters.selector;
    marketMakingEngineConfigBranchSelectors[2] =
        MarketMakingEngineConfigurationBranch.createCustomReferralCode.selector;
    marketMakingEngineConfigBranchSelectors[3] = MarketMakingEngineConfigurationBranch.createVault.selector;
    marketMakingEngineConfigBranchSelectors[4] =
        MarketMakingEngineConfigurationBranch.getCustomReferralCodeReferrer.selector;
    marketMakingEngineConfigBranchSelectors[5] = MarketMakingEngineConfigurationBranch.initialize.selector;
    marketMakingEngineConfigBranchSelectors[6] =
        MarketMakingEngineConfigurationBranch.updateVaultConfiguration.selector;
    marketMakingEngineConfigBranchSelectors[7] = MarketMakingEngineConfigurationBranch.setPercentageRatio.selector;
    marketMakingEngineConfigBranchSelectors[8] = MarketMakingEngineConfigurationBranch.getPercentageRatio.selector;

    bytes4[] memory vaultRouterBranchSelectors = new bytes4[](7);
    vaultRouterBranchSelectors[0] = VaultRouterBranch.deposit.selector;
    vaultRouterBranchSelectors[1] = VaultRouterBranch.getIndexTokenSwapRate.selector;
    vaultRouterBranchSelectors[2] = VaultRouterBranch.getVaultData.selector;
    vaultRouterBranchSelectors[3] = VaultRouterBranch.initiateWithdrawal.selector;
    vaultRouterBranchSelectors[4] = VaultRouterBranch.redeem.selector;
    vaultRouterBranchSelectors[5] = VaultRouterBranch.stake.selector;
    vaultRouterBranchSelectors[6] = VaultRouterBranch.unstake.selector;

    bytes4[] memory feeDistributionBranchSelectors = new bytes4[](5);
    feeDistributionBranchSelectors[0] = FeeDistributionBranch.getEarnedFees.selector;
    feeDistributionBranchSelectors[1] = FeeDistributionBranch.receiveOrderFee.selector;
    feeDistributionBranchSelectors[2] = FeeDistributionBranch.convertAccumulatedFeesToWeth.selector;
    feeDistributionBranchSelectors[3] = FeeDistributionBranch.sendWethToFeeRecipients.selector;
    feeDistributionBranchSelectors[4] = FeeDistributionBranch.claimFees.selector;


    selectors[0] = marketMakingEngineConfigBranchSelectors;
    selectors[1] = vaultRouterBranchSelectors;
    selectors[2] = feeDistributionBranchSelectors;

    return selectors;
}

function deployMarketMakingHarnesses(RootProxy.BranchUpgrade[] memory branchUpgrades)
    returns (RootProxy.BranchUpgrade[] memory)
{
    address[] memory harnesses = deployMarketMakingAddressHarnesses();

    bytes4[][] memory harnessesSelectors = getMarketMakingHarnessSelectors();

    RootProxy.BranchUpgrade[] memory harnessesUpgrades =
        getBranchUpgrades(harnesses, harnessesSelectors, RootProxy.BranchUpgradeAction.Add);

    uint256 cachedBranchUpgradesLength = branchUpgrades.length;
    uint256 maxLength = cachedBranchUpgradesLength + harnessesUpgrades.length;

    RootProxy.BranchUpgrade[] memory brancheAndHarnessesUpgrades = new RootProxy.BranchUpgrade[](maxLength);

    for (uint256 i; i < maxLength; i++) {
        brancheAndHarnessesUpgrades[i] =
            i < cachedBranchUpgradesLength ? branchUpgrades[i] : harnessesUpgrades[i - cachedBranchUpgradesLength];
    }

    return brancheAndHarnessesUpgrades;
}

function deployMarketMakingAddressHarnesses() returns (address[] memory) {
    address[] memory addressHarnesses = new address[](8);

    address vaultHarness = address(new VaultHarness());
    console.log("VaultHarness: ", vaultHarness);

    address withdrawalRequestHarness = address(new WithdrawalRequestHarness());
    console.log("WithdrawalRequestHarness: ", withdrawalRequestHarness);

    address collateralHarness = address(new CollateralHarness());
    console.log("CollateralHarness: ", collateralHarness);

    address distributionHarness = address(new DistributionHarness());
    console.log("DistributionHarness: ", distributionHarness);

    address marketDebtHarness = address(new MarketDebtHarness());
    console.log("MarketDebtHarness: ", marketDebtHarness);

    address marketMakingEngineConfigurationHarness = address(new MarketMakingEngineConfigurationHarness());
    console.log("MarketMakingEngineConfigurationHarness: ", marketMakingEngineConfigurationHarness);
    
    address swapRouterHarness = address(new SwapRouterHarness());
    console.log("SwapRouterHarness: ", swapRouterHarness);


    address feeRecipientHarness = address(new FeeRecipientHarness());
    console.log("FeeRecipientHarness: ", feeRecipientHarness);

    addressHarnesses[0] = vaultHarness;
    addressHarnesses[1] = withdrawalRequestHarness;
    addressHarnesses[2] = collateralHarness;
    addressHarnesses[3] = distributionHarness;
    addressHarnesses[4] = marketDebtHarness;
    addressHarnesses[5] = marketMakingEngineConfigurationHarness;
    addressHarnesses[6] = swapRouterHarness;
    addressHarnesses[7] = feeRecipientHarness;

    return addressHarnesses;
}

function getMarketMakingHarnessSelectors() pure returns (bytes4[][] memory) {
    bytes4[][] memory selectors = new bytes4[][](8);

    bytes4[] memory vaultHarnessSelectors = new bytes4[](10);
    vaultHarnessSelectors[0] = VaultHarness.workaround_Vault_getIndexToken.selector;
    vaultHarnessSelectors[1] = VaultHarness.workaround_Vault_getActorStakedShares.selector;
    vaultHarnessSelectors[2] = VaultHarness.workaround_Vault_getTotalStakedShares.selector;
    vaultHarnessSelectors[3] = VaultHarness.workaround_Vault_getWithdrawDelay.selector;
    vaultHarnessSelectors[4] = VaultHarness.workaround_Vault_getDepositCap.selector;
    vaultHarnessSelectors[5] = VaultHarness.exposed_Vault_create.selector;
    vaultHarnessSelectors[6] = VaultHarness.exposed_Vault_update.selector;
    vaultHarnessSelectors[7] = VaultHarness.workaround_Vault_getVaultAsset.selector;
    vaultHarnessSelectors[8] = VaultHarness.workaround_Vault_setTotalStakedShares.selector;
    vaultHarnessSelectors[9] = VaultHarness.workaround_Vault_getValuePerShare.selector;

    bytes4[] memory collateralHarnessSelectors = new bytes4[](2);
    collateralHarnessSelectors[0] = CollateralHarness.exposed_Collateral_load.selector;
    collateralHarnessSelectors[1] = CollateralHarness.workaround_Collateral_setParams.selector;

    bytes4[] memory withdrawalRequestHarnessSelectors = new bytes4[](1);
    withdrawalRequestHarnessSelectors[0] = WithdrawalRequestHarness.exposed_WithdrawalRequest_load.selector;

    bytes4[] memory distributionHarnessSelectors = new bytes4[](4);
    distributionHarnessSelectors[0] = DistributionHarness.exposed_setActorShares.selector;
    distributionHarnessSelectors[1] = DistributionHarness.exposed_distributeValue.selector;
    distributionHarnessSelectors[2] = DistributionHarness.exposed_accumulateActor.selector;
    distributionHarnessSelectors[3] = DistributionHarness.exposed_getActorValueChange.selector;

    bytes4[] memory marketDebtHarnessSelectors = new bytes4[](6);
    marketDebtHarnessSelectors[0] = MarketDebtHarness.workaround_getMarketId.selector;
    marketDebtHarnessSelectors[1] = MarketDebtHarness.workaround_setMarketId.selector;
    marketDebtHarnessSelectors[2] = MarketDebtHarness.workaround_getFeeRecipientsFees.selector;
    marketDebtHarnessSelectors[3] = MarketDebtHarness.workaround_getReceivedOrderFees.selector;
    marketDebtHarnessSelectors[4] = MarketDebtHarness.workaround_setFeeRecipientsFees.selector;
    marketDebtHarnessSelectors[5] = MarketDebtHarness.workaround_setConnectedVaults.selector;

    bytes4[] memory marketMakingEngineConfigurationSelectors = new bytes4[](3);
    marketMakingEngineConfigurationSelectors[0] = MarketMakingEngineConfigurationHarness.workaround_setWethAddress.selector;
    marketMakingEngineConfigurationSelectors[1] = 
        MarketMakingEngineConfigurationHarness.workaround_setPerpsEngineAddress.selector;
    marketMakingEngineConfigurationSelectors[2] = 
        MarketMakingEngineConfigurationHarness.workaround_setFeeRecipients.selector;

    bytes4[] memory swapRouterHarnessSelectors = new bytes4[](4);
    swapRouterHarnessSelectors[0] = SwapRouterHarness.exposed_setSwapStrategy.selector;
    swapRouterHarnessSelectors[1] = SwapRouterHarness.exposed_setPoolFee.selector;
    swapRouterHarnessSelectors[2] = SwapRouterHarness.exposed_setSlippageTolerance.selector;
    swapRouterHarnessSelectors[3] = SwapRouterHarness.exposed_swapStrategy_load.selector;

    bytes4[] memory feeRecipientHarnessSelectors = new bytes4[](2);
    feeRecipientHarnessSelectors[0] = FeeRecipientHarness.exposed_FeeRecipient_load.selector;
    feeRecipientHarnessSelectors[1] = FeeRecipientHarness.workaround_setFeeRecipientShares.selector;

    selectors[0] = vaultHarnessSelectors;
    selectors[1] = withdrawalRequestHarnessSelectors;
    selectors[2] = collateralHarnessSelectors;
    selectors[3] = distributionHarnessSelectors;
    selectors[4] = marketDebtHarnessSelectors;
    selectors[5] = marketMakingEngineConfigurationSelectors;
    selectors[6] = swapRouterHarnessSelectors;
    selectors[7] = feeRecipientHarnessSelectors;

    return selectors;
}

// Shared Utils

function getBranchUpgrades(
    address[] memory branches,
    bytes4[][] memory branchesSelectors,
    RootProxy.BranchUpgradeAction action
)
    pure
    returns (RootProxy.BranchUpgrade[] memory)
{
    require(branches.length == branchesSelectors.length, "TreeProxyUtils: branchesSelectors length mismatch");
    RootProxy.BranchUpgrade[] memory branchUpgrades = new RootProxy.BranchUpgrade[](branches.length);

    for (uint256 i; i < branches.length; i++) {
        bytes4[] memory selectors = branchesSelectors[i];
        branchUpgrades[i] = RootProxy.BranchUpgrade({ branch: branches[i], action: action, selectors: selectors });
    }

    return branchUpgrades;
}
