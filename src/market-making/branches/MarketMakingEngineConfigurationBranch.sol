// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { StabilityConfiguration } from "@zaros/market-making/leaves/StabilityConfiguration.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Market } from "src/market-making/leaves/Market.sol";
import { DexSwapStrategy } from "src/market-making/leaves/DexSwapStrategy.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { ZlpVault } from "@zaros/zlp/ZlpVault.sol";
import { UsdTokenSwap } from "@zaros/market-making/leaves/UsdTokenSwap.sol";
import { IReferral } from "@zaros/referral/interfaces/IReferral.sol";

// Open Zeppelin Upgradeable dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";

// TODO: add initializer at upgrade branch or auth branch
contract MarketMakingEngineConfigurationBranch is OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using DexSwapStrategy for DexSwapStrategy.Data;

    constructor() {
        _disableInitializers();
    }

    /// @notice Emitted when an engine is registered.
    /// @param engine The address of the engine contract.
    event LogRegisterEngine(address engine);

    /// @notice Emitted when a new vault is created.
    /// @param sender The address that created the vault.
    /// @param vaultId The vault id.
    event LogCreateVault(address indexed sender, uint128 vaultId);

    /// @notice Emitted when a vault is updated.
    /// @param sender The address that updated the vault.
    /// @param vaultId The vault id.
    event LogUpdateVaultConfiguration(address indexed sender, uint128 vaultId);

    /// @notice Emitted when a system keeper is configured.
    /// @param systemKeeper The address of the system keeper.
    /// @param shouldBeEnabled A flag indicating whether the system keeper should be enabled.
    event LogConfigureSystemKeeper(address systemKeeper, bool shouldBeEnabled);

    /// @notice Emitted when an engine's configuration is updated.
    /// @param engine The address of the engine contract.
    /// @param usdToken The address of the USD token contract.
    /// @param shouldBeEnabled A flag indicating whether the engine should be enabled or disabled.
    event LogConfigureEngine(address engine, address usdToken, bool shouldBeEnabled);

    /// @notice Emitted when collateral is configured.
    /// @param collateral The address of the collateral.
    /// @param priceAdapter The address of the price adapter.
    /// @param creditRatio The credit ratio.
    /// @param isEnabled The status of the collateral.
    /// @param decimals The decimals of the collateral.
    event LogConfigureCollateral(
        address indexed collateral, address priceAdapter, uint256 creditRatio, bool isEnabled, uint8 decimals
    );

    /// @notice Emitted when market is configured.
    /// @param engine The address of the perps engine.
    /// @param marketId The perps engine's market id.
    /// @param autoDeleverageStartThreshold The auto deleverage start threshold.
    /// @param autoDeleverageEndThreshold The auto deleverage end threshold.
    /// @param autoDeleveragePowerScale The auto deleverage power scale.
    event LogConfigureMarket(
        address engine,
        uint128 marketId,
        uint128 autoDeleverageStartThreshold,
        uint128 autoDeleverageEndThreshold,
        uint128 autoDeleveragePowerScale
    );

    /// @notice Emitted when a dex swap strategy is configured.
    /// @param dexSwapStrategyId The dex swap strategy id.
    /// @param dexAdapter The address of the dex adapter.
    event LogConfigureDexSwapStrategy(uint128 dexSwapStrategyId, address dexAdapter);

    /// @notice Emitted when the wETH address is set or updated.
    /// @param weth The address of the wETH token.
    event LogSetWeth(address weth);

    /// @notice Emitted when a fee recipient is configured.
    /// @param feeRecipient The address of the fee recipient.
    /// @param share The share of the fee recipient, example 0.5e18 (50%).
    event LogConfigureFeeRecipient(address feeRecipient, uint256 share);

    /// @notice Emitted when connected markets are configured on a vault.
    /// @param vaultId The vault id.
    /// @param marketsIds The markets ids.
    event LogConfigureVaultConnectedMarkets(uint128 vaultId, uint128[] marketsIds);

    /// @notice Emitted whe the referral module is configured.
    /// @param sender The address that configured the referral module.
    /// @param referralModule The address of the referral module.
    event LogConfigureReferralModule(address sender, address referralModule);

    /// @notice Returns the address of custom referral code
    /// @param customReferralCode The custom referral code.
    /// @return referrer The address of the referrer.
    function getCustomReferralCodeReferrer(string memory customReferralCode) external view returns (address) { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function configureSystemParameters() external onlyOwner { }

    /// @notice Creates a custom referral code.
    /// @param referrer The address of the referrer.
    /// @param customReferralCode The custom referral code.
    function createCustomReferralCode(address referrer, string memory customReferralCode) external onlyOwner {
        // load the market making engine configuration from storage
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // load the referral module
        IReferral referralModule = IReferral(marketMakingEngineConfiguration.referralModule);

        // create the custom referral code
        referralModule.createCustomReferralCode(referrer, customReferralCode);
    }

    /// @dev Invariants involved in the call:
    /// Must NOT be able to create a vault with id set to 0
    function createVault(Vault.CreateParams calldata params) external onlyOwner {
        if (params.indexToken == address(0)) {
            revert Errors.ZeroInput("indexToken");
        }

        if (params.depositCap == 0) {
            revert Errors.ZeroInput("depositCap");
        }

        if (params.withdrawalDelay == 0) {
            revert Errors.ZeroInput("withdrawDelay");
        }

        if (params.vaultId == 0) {
            revert Errors.ZeroInput("vaultId");
        }

        Vault.create(params);

        emit LogCreateVault(msg.sender, params.vaultId);
    }

    /// @dev Invariants involved in the call:
    /// Must NOT be able to update vault with id set to 0
    function updateVaultConfiguration(Vault.UpdateParams calldata params) external onlyOwner {
        if (params.depositCap == 0) {
            revert Errors.ZeroInput("depositCap");
        }

        if (params.withdrawalDelay == 0) {
            revert Errors.ZeroInput("withdrawDelay");
        }

        if (params.vaultId == 0) {
            revert Errors.ZeroInput("vaultId");
        }

        Vault.update(params);

        emit LogUpdateVaultConfiguration(msg.sender, params.vaultId);
    }

    /// @notice Configure connected markets on vault
    /// @dev Only owner can call this function
    /// @param vaultId The vault id.
    /// @param marketsIds The markets ids.
    function configureVaultConnectedMarkets(uint128 vaultId, uint128[] calldata marketsIds) external onlyOwner {
        // revert if vaultId is set to zero
        if (vaultId == 0) {
            revert Errors.ZeroInput("vaultId");
        }

        // revert if marketsIds is empty
        if (marketsIds.length == 0) {
            revert Errors.ZeroInput("connectedMarketsIds");
        }

        // load vault data from storage
        Vault.Data storage vault = Vault.load(vaultId);

        // push new array of connectd markets
        vault.connectedMarkets.push();

        // add markets ids to connected markets
        for (uint256 i; i < marketsIds.length; i++) {
            // use [vault.connectedMarkets.length - 1] to get the last connected markets array
            vault.connectedMarkets[vault.connectedMarkets.length - 1].add(marketsIds[i]);
        }

        // emit event LogConfigureVaultConnectedMarkets
        emit LogConfigureVaultConnectedMarkets(vaultId, marketsIds);
    }

    /// @notice Configure system keeper on Market Making Engine
    /// @dev Only owner can call this function
    /// @param systemKeeper The address of the system keeper.
    /// @param shouldBeEnabled The status of the system keeper.
    function configureSystemKeeper(address systemKeeper, bool shouldBeEnabled) external onlyOwner {
        // revert if systemKeeper is set to zero
        if (systemKeeper == address(0)) revert Errors.ZeroInput("systemKeeper");

        // loads the mm engine config storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // update system keeper status
        marketMakingEngineConfiguration.isSystemKeeperEnabled[systemKeeper] = shouldBeEnabled;

        // emit event LogConfigureSystemKeeper
        emit LogConfigureSystemKeeper(systemKeeper, shouldBeEnabled);
    }

    /// @notice Configures an engine contract and sets its linked USD token address.
    /// @dev This function can be used to enable or disable an active engine contract.
    /// @param engine The address of the engine contract.
    /// @param usdToken The address of the USD token contract.
    /// @param shouldBeEnabled A flag indicating whether the engine should be enabled.
    function configureEngine(address engine, address usdToken, bool shouldBeEnabled) external onlyOwner {
        if (engine == address(0)) revert Errors.ZeroInput("engine");

        // loads the mm engine config storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // if the engine needs to be disabled, set the isRegisteredEngine flag to false
        if (!shouldBeEnabled) {
            marketMakingEngineConfiguration.isRegisteredEngine[engine] = false;
            // sets the engine's usd token address to zero
            marketMakingEngineConfiguration.usdTokenOfEngine[engine] = address(0);

            emit LogConfigureEngine(engine, address(0), shouldBeEnabled);

            return;
        }

        // if the engine should be registered or the usd token updated, it mustn't be the zero address
        if (usdToken == address(0)) revert Errors.ZeroInput("usdToken");

        // registers the given engine if not already registered
        if (!marketMakingEngineConfiguration.isRegisteredEngine[engine]) {
            marketMakingEngineConfiguration.isRegisteredEngine[engine] = true;
        }

        // sets the USD token address of the given engine
        marketMakingEngineConfiguration.usdTokenOfEngine[engine] = usdToken;

        emit LogConfigureEngine(engine, usdToken, shouldBeEnabled);
    }

    /// @notice Set the wETH address
    /// @dev Only owner can call this function
    /// @param weth The address of the wETH token.
    function setWeth(address weth) external onlyOwner {
        // revert if weth is set to zero
        if (weth == address(0)) revert Errors.ZeroInput("wEth");

        // update weth address
        MarketMakingEngineConfiguration.load().weth = weth;

        // emit event LogSetWeth
        emit LogSetWeth(weth);
    }

    /// @notice Configure collateral on Market Making Engine
    /// @dev Only owner can call this functions
    /// @param collateral The address of the collateral.
    /// @param priceAdapter The address of the price adapter.
    /// @param creditRatio The credit ratio.
    /// @param isEnabled The status of the collateral.
    /// @param decimals The decimals of the collateral.
    function configureCollateral(
        address collateral,
        address priceAdapter,
        uint256 creditRatio,
        bool isEnabled,
        uint8 decimals
    )
        external
        onlyOwner
    {
        // check if collateral is set to zero
        if (collateral == address(0)) revert Errors.ZeroInput("collateral");

        // check if price adapter is set to zero
        if (priceAdapter == address(0)) revert Errors.ZeroInput("priceAdapter");

        // check id credit ratio is set to zero
        if (creditRatio == 0) revert Errors.ZeroInput("creditRatio");

        // check if decimals is set to zero
        if (decimals == 0) revert Errors.ZeroInput("decimals");

        // load collateral data from storage
        Collateral.Data storage collateralData = Collateral.load(collateral);

        // update collateral data
        collateralData.asset = collateral;
        collateralData.priceAdapter = priceAdapter;
        collateralData.creditRatio = creditRatio;
        collateralData.isEnabled = isEnabled;
        collateralData.decimals = decimals;

        // emit event LogConfigureCollateral
        emit LogConfigureCollateral(collateral, priceAdapter, creditRatio, isEnabled, decimals);
    }

    /// @notice Configure market on Market Making Engine
    /// @dev Only owner can call this functions
    /// @param engine The address of the engine.
    /// @param marketId The market id.
    /// @param autoDeleverageStartThreshold The auto deleverage start threshold.
    /// @param autoDeleverageEndThreshold The auto deleverage end threshold.
    /// @param autoDeleveragePowerScale The auto deleverage power scale.
    function configureMarket(
        address engine,
        uint128 marketId,
        uint128 autoDeleverageStartThreshold,
        uint128 autoDeleverageEndThreshold,
        uint128 autoDeleveragePowerScale
    )
        external
        onlyOwner
    {
        // revert if engine is set to zero
        if (engine == address(0)) revert Errors.ZeroInput("engine");

        // revert if marketId is set to zero
        if (marketId == 0) revert Errors.ZeroInput("marketId");

        // revert if autoDeleverageStartThreshold is set to zero
        if (autoDeleverageStartThreshold == 0) revert Errors.ZeroInput("autoDeleverageStartThreshold");

        // revert if autoDeleverageEndThreshold is set to zero
        if (autoDeleverageEndThreshold == 0) revert Errors.ZeroInput("autoDeleverageEndThreshold");

        // revert if autoDeleveragePowerScale is set to zero
        if (autoDeleveragePowerScale == 0) revert Errors.ZeroInput("autoDeleveragePowerScale");

        // load market data from storage
        Market.Data storage market = Market.load(marketId);

        // update market data
        market.engine = engine;
        market.id = marketId;
        market.autoDeleverageStartThreshold = autoDeleverageStartThreshold;
        market.autoDeleverageEndThreshold = autoDeleverageEndThreshold;
        market.autoDeleveragePowerScale = autoDeleveragePowerScale;

        // emit event LogConfigureMarket
        emit LogConfigureMarket(
            engine, marketId, autoDeleverageStartThreshold, autoDeleverageEndThreshold, autoDeleveragePowerScale
        );
    }

    /// @notice Configure dex swap strategy on Market Making Engine
    /// @dev Only owner can call this function
    /// @param dexSwapStrategyId The dex swap strategy id.
    /// @param dexAdapter The address of the dex adapter.
    function configureDexSwapStrategy(uint128 dexSwapStrategyId, address dexAdapter) external onlyOwner {
        // revert if dexSwapStrategyId is set to zero
        if (dexSwapStrategyId == 0) revert Errors.ZeroInput("dexSwapStrategyId");

        // revert if dexAdapter is set to zero
        if (dexAdapter == address(0)) revert Errors.ZeroInput("dexAdapter");

        // load dex swap strategy data from storage
        DexSwapStrategy.Data storage dexSwapStrategy = DexSwapStrategy.load(dexSwapStrategyId);

        // update dex swap strategy data
        dexSwapStrategy.id = dexSwapStrategyId;
        dexSwapStrategy.dexAdapter = dexAdapter;

        // emit event LogConfigureDexSwapStrategy
        emit LogConfigureDexSwapStrategy(dexSwapStrategyId, dexAdapter);
    }

    /// @notice Configure fee recipient on Market Making Engine
    /// @dev Only owner can call this function
    /// @dev The share is in 1e18 precision, example: 0.5e18 (50%), the sum of all shares must not exceed 1e18 (100%),
    /// if pass it will revert.
    /// @param feeRecipient The address of the fee recipient.
    /// @param share The share of the fee recipient, example: 0.5e18 (50%).
    function configureFeeRecipient(address feeRecipient, uint256 share) external onlyOwner {
        // revert if protocolFeeRecipient is set to zero
        if (feeRecipient == address(0)) revert Errors.ZeroInput("feeRecipient");

        // load market making engine configuration data from storage
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // check if share is greater than zero to verify the total will not exceed the maximum shares
        if (share > 0) {
            UD60x18 totalFeeRecipientsSharesX18 = marketMakingEngineConfiguration.getTotalFeeRecipientsShares();

            if (totalFeeRecipientsSharesX18.add(ud60x18(share)).gt(ud60x18(Constants.MAX_SHARES))) {
                revert Errors.FeeRecipientShareExceedsOne();
            }
        }

        // update protocol fee recipient
        marketMakingEngineConfiguration.protocolFeeRecipients.set(feeRecipient, share);

        // emit event LogConfigureFeeRecipient
        emit LogConfigureFeeRecipient(feeRecipient, share);
    }

    /// @notice Updates the stability configuration settings, including the Chainlink verifier and maximum
    /// verification delay.
    /// @param chainlinkVerifier The address of the Chainlink verifier contract to be used for price verification.
    /// @param maxVerificationDelay The maximum allowed delay, in seconds, for price verification.
    function updateStabilityConfiguration(
        address chainlinkVerifier,
        uint128 maxVerificationDelay
    )
        external
        onlyOwner
    {
        if (chainlinkVerifier == address(0)) {
            revert Errors.ZeroInput("chainlinkVerifier");
        }

        if (maxVerificationDelay == 0) {
            revert Errors.ZeroInput("maxVerificationDelay");
        }

        StabilityConfiguration.update(chainlinkVerifier, maxVerificationDelay);
    }

    /// @notice Updates the asset allowance for a specific vault.
    /// @param vaultId The ID of the vault for which the asset allowance is being updated.
    /// @param allowance The new asset allowance amount to be set for the vault's index token.
    function updateVaultAssetAllowance(uint128 vaultId, uint256 allowance) external onlyOwner {
        Vault.Data storage vault = Vault.load(vaultId);

        ZlpVault(vault.indexToken).updateAssetAllowance(allowance);
    }

    /// @notice Configures the USD token swap parameters.
    /// @param baseFeeUsd The base fee applied to each swap.
    /// @param swapSettlementFeeBps The settlement fee in basis points applied to each swap.
    /// @param maxExecutionTime The maximum allowable time (in seconds) for swap execution.
    function configureUsdTokenSwap(
        uint128 baseFeeUsd,
        uint128 swapSettlementFeeBps,
        uint128 maxExecutionTime
    )
        external
        onlyOwner
    {
        if (maxExecutionTime == 0) {
            revert Errors.ZeroInput("maxExecutionTime");
        }

        UsdTokenSwap.update(baseFeeUsd, swapSettlementFeeBps, maxExecutionTime);
    }

    /// @notice Retrieves the collateral data for a given asset.
    /// @param asset The address of the asset for which the collateral data is being retrieved.
    /// @return The collateral data associated with the specified asset.
    function getCollateralData(address asset) external pure returns (Collateral.Data memory) {
        return Collateral.load(asset);
    }
    /// @notice Configures the referral module.
    /// @dev Only owner can configure the referral module.
    /// @param referralModule The address of the referral module.

    function configureReferralModule(address referralModule) external onlyOwner {
        // revert if the referral module is zero
        if (referralModule == address(0)) {
            revert Errors.ZeroInput("referralModule");
        }

        // load the perps engine configuration from storage
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // set the referral module
        marketMakingEngineConfiguration.referralModule = referralModule;

        // emit the LogConfigureReferralModule event
        emit LogConfigureReferralModule(msg.sender, referralModule);
    }
}
