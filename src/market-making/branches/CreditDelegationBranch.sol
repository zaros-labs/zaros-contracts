// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { EngineAccessControl } from "@zaros/utils/EngineAccessControl.sol";
import { SwapExactInputSinglePayload, SwapExactInputPayload } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { UsdToken } from "@zaros/usd/UsdToken.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { DexSwapStrategy } from "@zaros/market-making/leaves/DexSwapStrategy.sol";
import { Market } from "@zaros/market-making/leaves/Market.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, ZERO as SD59x18_ZERO, unary } from "@prb-math/SD59x18.sol";

/// @dev This contract deals with USDC to settle protocol debt, used to back USD Token
contract CreditDelegationBranch is EngineAccessControl {
    using Collateral for Collateral.Data;
    using DexSwapStrategy for DexSwapStrategy.Data;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using Market for Market.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using Vault for Vault.Data;

    /*//////////////////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a system keeper converts a market's assets deposited as credit to USDC.
    /// @param marketId The market identifier.
    /// @param asset The asset used for credit deposits to be settled for USDC.
    /// @param assetAmount The token amount of assets deposited as credit.
    /// @param usdcOut The amount of USDC received from the swap.
    event LogConvertMarketCreditDepositsToUsdc(
        uint128 indexed marketId, address asset, uint256 assetAmount, uint256 usdcOut
    );

    /// @notice Emitted when the market making engine receives margin collateral from an engine.
    /// @param engine The address of the engine that called the function.
    /// @param marketId The engine's market id.
    /// @param collateralType The margin collateral address.
    /// @param amount The token amount of collateral received.
    event LogDepositCreditForMarket(
        address indexed engine, uint128 indexed marketId, address collateralType, uint256 amount
    );

    /// @notice Emitted when the perps engine requests USD Token to be minted by the market making engine.
    /// @param engine The address of the engine that called the function.
    /// @param marketId The engine's market id.
    /// @param requestedUsdTokenAmount The requested amount of USD Token to minted.
    /// @param mintedUsdTokenAmount The actual amount of USD Token minted, potentially factored by the market's auto
    /// deleverage
    /// system.
    event LogWithdrawUsdTokenFromMarket(
        address indexed engine,
        uint128 indexed marketId,
        uint256 requestedUsdTokenAmount,
        uint256 mintedUsdTokenAmount
    );

    /// @notice Emitted when a vault's debt or credit is settled.
    /// @dev Some of the emitted values are zero depending on the vault's state.
    /// @param vaultId The vault identifier.
    /// @param assetsBought The amount of assets bought.
    /// @param assetsSold The amount of assets sold.
    /// @param usdcBought The amount of USDC bought.
    /// @param usdcSold The amount of USDC sold.
    /// @param usdTokensIssuedAndSold The amount of USD Tokens issued and sold.
    event LogSettleVaultDebt(
        uint128 indexed vaultId,
        uint256 assetsBought,
        uint256 assetsSold,
        uint256 usdcBought,
        uint256 usdcSold,
        uint256 usdTokensIssuedAndSold
    );

    /*//////////////////////////////////////////////////////////////////////////
                                   VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Returns the credit capacity of the given market id.
    /// @dev `CreditDelegationBranch::updateCreditDelegation` must be called before calling this function in order to
    /// retrieve the latest state.
    /// @dev Each engine can implement its own debt accounting schema according to its business logic, thus, this
    /// function will simply return the credit capacity in USD for the given market id.
    /// @dev Invariants:
    /// The Market MUST exist.
    /// @param marketId The engine's market id.
    /// @return creditCapacityUsdX18 The current credit capacity of the given market id in USD.
    function getCreditCapacityForMarketId(uint128 marketId) public view returns (SD59x18) {
        Market.Data storage market = Market.loadExisting(marketId);

        return Market.getCreditCapacityUsd(
            market.getTotalDelegatedCreditUsd(), market.getUnrealizedDebtUsd().add(market.getRealizedDebtUsd())
        );
    }

    /// @notice Returns the adjusted profit of an active position at the given market id, considering the market's ADL
    /// state.
    /// @dev If the market is in its default state, it will simply return the provided profit. Otherwise, it will
    /// adjust based on the configured ADL parameters.
    /// @dev Invariants:
    /// The Market of `marketId` MUST exist.
    /// The Market of `marketId` MUST be live.
    /// @param marketId The engine's market id.
    /// @param profitUsd The position's profit in USD.
    /// @return adjustedProfitUsdX18 The adjusted profit in USD Token, according to the market's health.
    function getAdjustedProfitForMarketId(
        uint128 marketId,
        uint256 profitUsd
    )
        public
        view
        returns (UD60x18 adjustedProfitUsdX18)
    {
        // load the market's data storage pointer
        Market.Data storage market = Market.loadLive(marketId);
        // cache the market's total debt
        SD59x18 marketTotalDebtUsdX18 = market.getUnrealizedDebtUsd().add(market.getRealizedDebtUsd());
        // uint256 -> UD60x18
        UD60x18 profitUsdX18 = ud60x18(profitUsd);

        // caches the market's delegated credit
        UD60x18 delegatedCreditUsdX18 = market.getTotalDelegatedCreditUsd();
        // caches the market's credit capacity
        SD59x18 creditCapacityUsdX18 = Market.getCreditCapacityUsd(delegatedCreditUsdX18, marketTotalDebtUsdX18);

        // if the credit capacity is less than or equal to zero, it means the total debt has already taken all the
        // delegated credit
        if (creditCapacityUsdX18.lte(SD59x18_ZERO)) {
            revert Errors.InsufficientCreditCapacity(marketId, creditCapacityUsdX18.intoInt256());
        }

        // we don't need to add `profitUsd` as it's assumed to be part of the total debt
        // NOTE: If we don't return the adjusted profit in this if branch, we assume marketTotalDebtUsdX18 is positive
        if (!market.isAutoDeleverageTriggered(delegatedCreditUsdX18, marketTotalDebtUsdX18)) {
            // if the market is not in the ADL state, it returns the profit as is
            adjustedProfitUsdX18 = profitUsdX18;
            return adjustedProfitUsdX18;
        }

        // if the market's auto deleverage system is triggered, it assumes marketTotalDebtUsdX18 > 0
        adjustedProfitUsdX18 =
            market.getAutoDeleverageFactor(delegatedCreditUsdX18, marketTotalDebtUsdX18).mul(profitUsdX18);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                REGISTERED ENGINE ONLY PROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Adds credit in form of a registered collateral type to the given market id.
    /// @dev Engines call this function to send collateral collected from their users and increase their credit
    /// capacity, rewarding the market making engine's LPs.
    /// @dev Called by the perps engine to send margin collateral deducted from a trader's account during a negative
    /// pnl settlement or a liquidation event.
    /// @dev The system must enforce that if a market is running by an engine, it must have some delegated credit. In
    /// order to delist a market and allow Vaults to fully undelegate the provided credit, it first must be disabled
    /// at the engine level in order to prevent users from being able to fulfill their expected profits.
    /// @param marketId The engine's market id.
    /// @param collateralType The margin collateral address.
    /// @param amount The token amount of collateral to receive.
    /// @dev Invariants:
    /// The Market of `marketId` MUST exist.
    /// The Market of `marketId` MUST be live.
    function depositCreditForMarket(
        uint128 marketId,
        address collateralType,
        uint256 amount
    )
        external
        onlyRegisteredEngine
    {
        if (amount == 0) revert Errors.ZeroInput("amount");
        // loads the collateral's data storage pointer
        Collateral.Data storage collateral = Collateral.load(collateralType);

        // reverts if collateral isn't supported
        collateral.verifyIsEnabled();

        // loads the market's data storage pointer
        Market.Data storage market = Market.loadLive(marketId);

        // ensures that the market has delegated credit, so the engine is not depositing credit to an empty
        // distribution (with 0 total shares), although this should never happen if the system functions properly.
        if (market.getTotalDelegatedCreditUsd().isZero()) {
            revert Errors.NoDelegatedCredit(marketId);
        }

        // uint256 -> UD60x18 and scale decimals to 18
        UD60x18 amountX18 = collateral.convertTokenAmountToUd60x18(amount);

        // caches the usdToken address
        address usdToken = MarketMakingEngineConfiguration.load().usdTokenOfEngine[msg.sender];

        if (collateralType == usdToken) {
            // if the deposited collateral is USD Token, it reduces the market's realized debt
            market.updateNetUsdTokenIssuance(unary(amountX18.intoSD59x18()));
        } else {
            // deposits the received collateral to the market to be distributed to vaults, and then settled in the
            // future
            market.depositCredit(collateralType, amountX18);
        }

        // transfers the margin collateral asset from the perps engine to the market making engine
        // NOTE: The engine must approve the market making engine to transfer the margin collateral asset, see
        // PerpsEngineConfigurationBranch::setMarketMakingEngineAllowance
        IERC20(collateralType).safeTransferFrom(msg.sender, address(this), amount);

        // emit an event
        emit LogDepositCreditForMarket(msg.sender, marketId, collateralType, amount);
    }

    /// @notice Mints the requested amount of USD Token to the caller and updates the market's
    /// debt state.
    /// @dev Called by a registered engine to mint USD Token to profitable traders.
    /// @dev USD Token association with an engine's user happens at the engine contract level.
    /// @dev We assume `amount` is part of the market's reported unrealized debt.
    /// @dev Invariants:
    /// The Market of `marketId` MUST exist.
    /// The Market of `marketId` MUST be live.
    /// @param marketId The engine's market id requesting USD Token.
    /// @param amount The amount of USD Token to mint.
    function withdrawUsdTokenFromMarket(uint128 marketId, uint256 amount) external onlyRegisteredEngine {
        // loads the market's data storage pointer
        Market.Data storage market = Market.loadLive(marketId);

        // load the market's connected vaults ids and `mstore` them
        uint256[] memory connectedVaults = market.getConnectedVaultsIds();

        // once the unrealized debt is distributed, we need to update the credit delegated by these vaults to the
        // market
        Vault.recalculateVaultsCreditCapacity(connectedVaults);

        // caches the market's unrealized debt
        SD59x18 unrealizedDebtUsdX18 = market.getUnrealizedDebtUsd();
        // caches the market's realized debt
        // note: we'll never need to rehydrate the market's credit deposits value cache here as its connected vauls'
        // credit capacities have just been updated above, performing all required debt state transitions of this
        // market as a side effect
        SD59x18 realizedUsdTokenDebtX18 = market.getRealizedDebtUsd();

        // cache the market's total debt
        SD59x18 marketTotalDebtUsdX18 = unrealizedDebtUsdX18.add(realizedUsdTokenDebtX18);

        // cache the market's delegated credit
        UD60x18 delegatedCreditUsdX18 = market.getTotalDelegatedCreditUsd();

        // cache the market's credit capacity
        SD59x18 creditCapacityUsdX18 = Market.getCreditCapacityUsd(delegatedCreditUsdX18, marketTotalDebtUsdX18);

        // enforces that the market has enough credit capacity, if it' a listed market it must always have some
        // delegated credit, see Vault.Data.lockedCreditRatio.
        // NOTE: additionally, the ADL system if functioning properly must ensure that the market always has credit
        // capacity to cover USD Token mint requests. Deleverage happens when the perps engine calls
        // CreditDelegationBranch::getAdjustedProfitForMarketId.
        // NOTE: however, it still is possible to fall into a scenario where the credit capacity is <= 0, as the
        // delegated credit may be provided in form of volatile collateral assets, which could go down in value as
        // debt reaches its ceiling. In that case, the market will run out of mintable USD Token and the mm engine
        // must
        // settle all outstanding debt for USDC, in order to keep previously paid USD Token fully backed.
        if (creditCapacityUsdX18.lt(SD59x18_ZERO)) {
            revert Errors.InsufficientCreditCapacity(marketId, creditCapacityUsdX18.intoInt256());
        }

        // uint256 -> UD60x18
        // NOTE: we don't need to scale decimals here as it's known that USD Token has 18 decimals
        UD60x18 amountX18 = ud60x18(amount);
        // prepare the amount of usdToken that will be minted to the perps engine
        uint256 amountToMint;

        // now we realize the added usd debt of the market
        // note: USD Token is assumed to be 1:1 with the system's usd accounting
        if (market.isAutoDeleverageTriggered(delegatedCreditUsdX18, marketTotalDebtUsdX18)) {
            // if the market is in the ADL state, it reduces the requested USD Token amount by multiplying it by the
            // ADL factor, which must be < 1
            UD60x18 adjustedUsdTokenToMintX18 =
                market.getAutoDeleverageFactor(delegatedCreditUsdX18, marketTotalDebtUsdX18).mul(amountX18);
            amountToMint = adjustedUsdTokenToMintX18.intoUint256();
            market.updateNetUsdTokenIssuance(adjustedUsdTokenToMintX18.intoSD59x18());
        } else {
            // if the market is not in the ADL state, it realizes the full requested USD Token amount
            amountToMint = amountX18.intoUint256();
            market.updateNetUsdTokenIssuance(amountX18.intoSD59x18());
        }

        // loads the market making engine configuration storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();
        // cache the USD Token address
        UsdToken usdToken = UsdToken(marketMakingEngineConfiguration.usdTokenOfEngine[msg.sender]);

        // mints USD Token to the perps engine
        usdToken.mint(msg.sender, amountToMint);

        // emit an event
        emit LogWithdrawUsdTokenFromMarket(msg.sender, marketId, amount, amountToMint);
    }

    /*//////////////////////////////////////////////////////////////////////////
                REGISTERED SYSTEM KEEPERS ONLY PROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    struct ConvertMarketsCreditDepositsToUsdcContext {
        address asset;
        uint128 dexSwapStrategyId;
        bytes path;
        UD60x18 assetAmountX18;
        uint256 usdcOut;
        UD60x18 netUsdcReceivedX18;
    }

    /// @notice Converts assets deposited as credit to a given market for USDC.
    /// @dev USDC accumulated by swaps is stored at markets, and later pushed to its connected vaults in order to
    /// cover an engine's usd token.
    /// @dev The keeper must ensure that the market has received fees for the given asset before calling this
    /// function.
    /// @dev The keeper doesn't need to settle all deposited assets at once, it can settle them in batches as needed.
    /// @param marketId The market identifier.
    /// @param assets The array of assets deposited as credit to be settled for USDC.
    /// @param dexSwapStrategyIds The identifier of the dex swap strategies to be used.
    /// @param paths Used when the keeper wants to perform a multihop swap using one of the swap strategies.
    function convertMarketsCreditDepositsToUsdc(
        uint128 marketId,
        address[] calldata assets,
        uint128[] calldata dexSwapStrategyIds,
        bytes[] calldata paths
    )
        external
        onlyRegisteredSystemKeepers
    {
        // revert if the arrays have different lengths
        if (assets.length != dexSwapStrategyIds.length || assets.length != paths.length) {
            // we ignore in purpose the error params here
            revert Errors.ArrayLengthMismatch(0, 0);
        }

        // define context
        ConvertMarketsCreditDepositsToUsdcContext memory ctx;

        // load the market's data storage pointer
        Market.Data storage market = Market.loadExisting(marketId);

        for (uint256 i; i < assets.length; i++) {
            // prepare the asset, dex swap strategy id and path
            ctx.asset = assets[i];
            ctx.dexSwapStrategyId = dexSwapStrategyIds[i];
            ctx.path = paths[i];

            // revert if the market hasn't received any fees for the given asset
            if (!market.creditDeposits.contains(ctx.asset)) revert Errors.MarketDoesNotContainTheAsset(ctx.asset);

            // get the amount of assets deposited as credit
            ctx.assetAmountX18 = ud60x18(market.creditDeposits.get(ctx.asset));

            // convert the assets to USDC
            ctx.usdcOut =
                _convertAssetsToUsdc(ctx.dexSwapStrategyId, ctx.asset, ctx.assetAmountX18, ctx.path, address(this));

            // load the usdc collateral data storage pointer
            Collateral.Data storage usdcCollateral = Collateral.load(MarketMakingEngineConfiguration.load().usdc);

            // uint256 -> UD60x18 with decimals conversion
            ctx.netUsdcReceivedX18 = usdcCollateral.convertTokenAmountToUd60x18(ctx.usdcOut);

            // settles the credit deposit for the amount of USDC receicevd
            market.settleCreditDeposit(ctx.asset, ctx.netUsdcReceivedX18);

            // emit an event
            emit LogConvertMarketCreditDepositsToUsdc(
                marketId, ctx.asset, ctx.assetAmountX18.intoUint256(), ctx.usdcOut
            );
        }
    }

    /// @notice Settles the given vaults' debt or credit by swapping assets to USDC or vice versa.
    /// @dev Converts ZLP Vaults unsettled debt to settled debt by:
    ///     - If in debt, swapping the vault's assets to USDC.
    ///     - If in credit, swapping the vault's available USDC to its underlying assets.
    /// exchange for their assets.
    /// @dev USDC acquired from onchain markets is deposited to vaults and used to cover future USD Token swaps, in
    /// case the vault is in debt.
    /// @dev If the vault is in net credit and doesn't own enough USDC to fully settle the due amount, it may have its
    /// assets rebalanced with other vaults through `CreditDelegation::rebalanceVaultsAssets`.
    /// @param vaultsIds The vaults' identifiers to settle.
    function settleVaultsDebt(uint256[] calldata vaultsIds) external onlyRegisteredSystemKeepers {
        // first, we need to update the credit capacity of the vaults
        Vault.recalculateVaultsCreditCapacity(vaultsIds);

        for (uint256 i; i < vaultsIds.length; i++) {
            // load the vault storage pointer
            Vault.Data storage vault = Vault.loadExisting(vaultsIds[i].toUint128());

            // cache the vault's unsettled debt
            SD59x18 vaultUnsettledRealizedDebtUsdX18 = vault.getUnsettledRealizedDebt();

            // cache the vault asset
            address vaultAsset = vault.collateral.asset;

            // cache the usdc address
            address usdc = MarketMakingEngineConfiguration.load().usdc;

            if (vaultUnsettledRealizedDebtUsdX18.isZero()) {
                // proceed to the next vault if the vault has no debt that needs to be settled
                continue;
            } else if (vaultUnsettledRealizedDebtUsdX18.lt(SD59x18_ZERO)) {
                // vault asset -> USDC
                // if the vault is in debt, it will swap its assets to USDC

                // loads the dex swap strategy data storage pointer
                DexSwapStrategy.Data storage dexSwapStrategy =
                    DexSwapStrategy.loadExisting(vault.swapStrategy.assetDexSwapStrategyId);

                // get swap amount
                uint256 swapAmount = calculateSwapAmount(
                    dexSwapStrategy.dexAdapter, vaultAsset, usdc, vaultUnsettledRealizedDebtUsdX18, usdc
                );

                // uint256 -> UD60x18
                UD60x18 swapAmountX18 = Collateral.load(vaultAsset).convertTokenAmountToUd60x18(swapAmount);

                // note: here you can call _convertAssetsToUsdc after determining the swap amount based on the vault
                // unsettled realized debt value / swap amount
                uint256 usdcOut = _convertAssetsToUsdc(
                    vault.swapStrategy.usdcDexSwapStrategyId,
                    vaultAsset,
                    swapAmountX18,
                    vault.swapStrategy.usdcDexSwapPath,
                    address(this)
                );

                // use the usdcOut to update the vault's state
                vault.depositedUsdc +=
                    Collateral.load(usdc).convertTokenAmountToUd60x18(usdcOut).intoUint256().toUint128();
            } else {
                // USDC -> vault asset
                // if the vault is in credit, it will swap its USDC previously accumulated from markets' and vaults'
                // deposits to its underlying assets

                // loads the dex swap strategy data storage pointer
                DexSwapStrategy.Data storage dexSwapStrategy =
                    DexSwapStrategy.loadExisting(vault.swapStrategy.assetDexSwapStrategyId);

                // get swap amount
                uint256 usdcOut = calculateSwapAmount(
                    dexSwapStrategy.dexAdapter, usdc, vaultAsset, vaultUnsettledRealizedDebtUsdX18, usdc
                );

                // get deposited USDC balance of the vault
                // note: change the following value to vault.depositedUsdc
                uint256 vaultUsdcBalance = vault.depositedUsdc;

                // if the vault doesn't have enough usdc use whatever amount it has
                usdcOut = (usdcOut <= vaultUsdcBalance) ? usdcOut : vaultUsdcBalance;

                UD60x18 usdcOutX18 = Collateral.load(usdc).convertTokenAmountToUd60x18(usdcOut);

                // note: here you can call _convertUsdcToAssets after determining the swap amount based on the vault
                // unsettled realized debt value / swap amount
                _convertUsdcToAssets(
                    vault.swapStrategy.assetDexSwapStrategyId,
                    vaultAsset,
                    usdcOutX18,
                    vault.swapStrategy.assetDexSwapPath,
                    vault.indexToken
                );

                vault.depositedUsdc -=
                    Collateral.load(usdc).convertTokenAmountToUd60x18(usdcOut).intoUint256().toUint128();
                // note: since you're buying assets, you should transfer the assets to the vault. You probably want to
                // use the vault's indexToken address as the swap recipient at convertUsdcToAssets
            }
        }
    }

    /// vault asset -> usdc
    /// @notice Calculates the amount of a specific vault asset needed to cover negative unsettled debt in USD.
    /// usdc -> vault asset
    /// @notice Calculates the amount of usdc needed to cover positive unsettled debt in USD.
    /// @param dexAdapter The address of the DEX adapter used for price calculation.
    /// @param assetIn The address of the vault asset to calculate the amount for.
    /// @param assetOut The address of the USDC token.
    /// @param vaultUnsettledRealizedDebtUsdX18 The unsettled debt in USD, represented in SD59x18 format.
    /// @param usdc The USDC token address
    /// @return amount The amount of the vault asset required to cover the unsettled debt in USD.
    function calculateSwapAmount(
        address dexAdapter,
        address assetIn,
        address assetOut,
        SD59x18 vaultUnsettledRealizedDebtUsdX18,
        address usdc
    )
        public
        view
        returns (uint256)
    {
        // get vault unsettled debt absolute value USDC in uint256
        uint256 vaultUnsettledDebtUsdAbs =
            Collateral.load(usdc).convertSd59x18ToTokenAmount(vaultUnsettledRealizedDebtUsdX18.abs());

        // calculate expected asset amount needed to cover the debt
        uint256 amount = IDexAdapter(dexAdapter).getExpectedOutput(assetOut, assetIn, vaultUnsettledDebtUsdAbs);

        return amount;
    }

    /// @notice Rebalances credit and debt between two vaults.
    /// @dev Since the protocol supports usdToken holders to redeem a ZLP Vault's underlying assets, it may enter a
    /// state where the relation between vaults' credit and debt is unbalanced. This function allows the system to fix
    /// this correlation by swapping assets of a vault in net debt for USDC and depositing the USDC to the vault in
    /// net credit, rebalancing the system. Accumulated USDC is later swapped back to the in credit vault's underlying
    /// assets at `CreditDelegationBranch::settleVaultsDebt`.
    /// @param vaultsIds The vaults' identifiers to rebalance.
    function rebalanceVaultsAssets(uint128[2] calldata vaultsIds) external onlyRegisteredSystemKeepers {
        // load the storage pointer of the vault in net credit
        Vault.Data storage inCreditVault = Vault.loadExisting(vaultsIds[0]);
        // load the storage pointer of the vault in net debt
        Vault.Data storage inDebtVault = Vault.loadExisting(vaultsIds[1]);

        // create an in-memory dynamic array in order to call `Vault::recalculateVaultsCreditCapacity`
        uint256[] memory vaultsIdsForRecalculation = new uint256[](2);

        vaultsIdsForRecalculation[0] = vaultsIds[0];
        vaultsIdsForRecalculation[1] = vaultsIds[1];

        // recalculate the credit capacity of both vaults
        Vault.recalculateVaultsCreditCapacity(vaultsIdsForRecalculation);

        // cache the in debt vault unsettled debt
        SD59x18 inDebtVaultUnsettledRealizedDebtUsdX18 = inDebtVault.getUnsettledRealizedDebt();
        // cache the in credit vault unsettled debt
        SD59x18 inCreditVaultUnsettledRealizedDebtUsdX18 = inCreditVault.getUnsettledRealizedDebt();

        // if the vault that is supposed to be in credit is not, or the vault that is supposed to be in debt is not,
        // revert
        if (
            inCreditVaultUnsettledRealizedDebtUsdX18.lte(SD59x18_ZERO)
                || inDebtVaultUnsettledRealizedDebtUsdX18.gte(SD59x18_ZERO)
        ) {
            revert Errors.InvalidVaultDebtSettlementRequest();
        }

        // get credit absolute value
        SD59x18 inCreditVaultUnsettledRealizedDebtUsdX18Abs = inCreditVaultUnsettledRealizedDebtUsdX18.abs();

        // if credit absolute value > debt, use debt value, else use credit value
        SD59x18 depositAmountUsdX18 = inCreditVaultUnsettledRealizedDebtUsdX18Abs.gt(
            inDebtVaultUnsettledRealizedDebtUsdX18
        ) ? inDebtVaultUnsettledRealizedDebtUsdX18 : inCreditVaultUnsettledRealizedDebtUsdX18Abs;

        // loads the dex swap strategy data storage pointer
        DexSwapStrategy.Data storage dexSwapStrategy =
            DexSwapStrategy.loadExisting(inDebtVault.swapStrategy.usdcDexSwapStrategyId);

        // load usdc
        address usdc = MarketMakingEngineConfiguration.load().usdc;

        // SD59x18 -> uint256
        uint256 depositAmountUsdc = Collateral.load(usdc).convertSd59x18ToTokenAmount(depositAmountUsdX18);

        // get collateral asset amount for usd value
        uint256 depositAmount = IDexAdapter(dexSwapStrategy.dexAdapter).getExpectedOutput(
            usdc, inDebtVault.collateral.asset, depositAmountUsdc
        );

        // prepare the data for executing the swap asset -> usdc
        SwapExactInputPayload memory swapCallData = SwapExactInputPayload({
            path: inDebtVault.swapStrategy.usdcDexSwapPath,
            tokenIn: inDebtVault.collateral.asset,
            tokenOut: usdc,
            amountIn: depositAmount,
            recipient: inCreditVault.indexToken // deposit the usdc to the in credit vault
         });

        // approve the collateral token to the dex adapter
        IERC20(inDebtVault.collateral.asset).approve(dexSwapStrategy.dexAdapter, depositAmount);

        // swap the credit deposit assets for USDC
        dexSwapStrategy.executeSwapExactInput(swapCallData);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   UNPROTECTED FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Updates the credit delegations from ZLP Vaults to the given market id.
    /// @dev Must be called whenever an engine needs to know the current credit capacity of a given market id.
    function updateMarketCreditDelegations(uint128 marketId) public {
        // load the market's data storage pointer
        Market.Data storage market = Market.loadLive(marketId);

        // load the market's connected vaults ids and `mstore` them
        uint256[] memory connectedVaults = market.getConnectedVaultsIds();

        // once the unrealized debt is distributed, we need to update the credit delegated by these vaults to the
        // market
        Vault.recalculateVaultsCreditCapacity(connectedVaults);
    }

    /// @notice Called by a registered to update a market's credit delegations and return its credit capacity.
    /// @param marketId The engine's market id.
    /// @return creditCapacityUsdX18 The current credit capacity of the given market id in USD.
    function updateMarketCreditDelegationsAndReturnCapacity(uint128 marketId) external returns (SD59x18) {
        updateMarketCreditDelegations(marketId);
        return getCreditCapacityForMarketId(marketId);
    }

    /// @notice Updates the credit capacity of the given vault id, recalculating its connected markets' debt and its
    /// collateral assets USD value.
    /// @param vaultId The vault identifier.
    function updateVaultCreditCapacity(uint128 vaultId) external {
        // prepare the `Vault::recalculateVaultsCreditCapacity` call
        uint256[] memory vaultsIds = new uint256[](1);
        vaultsIds[0] = uint256(vaultId);

        // updates the vault's credit capacity
        Vault.recalculateVaultsCreditCapacity(vaultsIds);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _convertAssetsToUsdc(
        uint128 dexSwapStrategyId,
        address asset,
        UD60x18 assetAmountX18,
        bytes memory path,
        address recipient
    )
        internal
        returns (uint256 usdcOut)
    {
        // revert if the amount is zero
        if (assetAmountX18.isZero()) revert Errors.AssetAmountIsZero(asset);

        // load the market making engine configuration storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // load the asset collateral data storage pointer
        Collateral.Data storage assetCollateralConfig = Collateral.load(asset);

        // convert the stored assets decimals from 18 to the underlying token decimals
        uint256 assetAmount = assetCollateralConfig.convertUd60x18ToTokenAmount(assetAmountX18);

        // cache the usdc address
        address usdc = marketMakingEngineConfiguration.usdc;

        // if the asset being handled is usdc, simply add it to `usdcOut`
        if (asset == usdc) {
            usdcOut = assetAmount;
        } else {
            // loads the dex swap strategy data storage pointer
            DexSwapStrategy.Data storage dexSwapStrategy = DexSwapStrategy.loadExisting(dexSwapStrategyId);

            // approve the asset to be spent by the dex adapter contract
            IERC20(asset).approve(dexSwapStrategy.dexAdapter, assetAmount);

            // verify if the swap should be input single or multihop
            if (path.length == 0) {
                // prepare the data for executing the swap
                SwapExactInputSinglePayload memory swapCallData = SwapExactInputSinglePayload({
                    tokenIn: asset,
                    tokenOut: usdc,
                    amountIn: assetAmount,
                    recipient: recipient
                });

                // swap the credit deposit assets for USDC and store the output amount
                usdcOut = dexSwapStrategy.executeSwapExactInputSingle(swapCallData);
            } else {
                // prepare the data for executing the swap
                SwapExactInputPayload memory swapCallData = SwapExactInputPayload({
                    path: path,
                    tokenIn: asset,
                    tokenOut: usdc,
                    amountIn: assetAmount,
                    recipient: recipient
                });

                // swap the credit deposit assets for USDC and store the output amount
                usdcOut = dexSwapStrategy.executeSwapExactInput(swapCallData);
            }

            // load the usdc collateral data storage pointer
            Collateral.Data storage usdcCollateral = Collateral.load(usdc);

            // cache the settlement base fee value using usdc's native decimals
            uint256 settlementBaseFeeUsd = usdcCollateral.convertUd60x18ToTokenAmount(
                ud60x18(marketMakingEngineConfiguration.settlementBaseFeeUsdX18)
            );

            // if there isn't enough usdc to conver the base fee, revert
            // NOTE: keepers must be configured to buy good chunks of usdc at minimum (e.g $500), as the settlement
            // base fee shouldn't be much greater than $1.
            if (usdcOut < settlementBaseFeeUsd) {
                revert Errors.FailedToPaySettlementBaseFee();
            }

            usdcOut -= settlementBaseFeeUsd;

            // distribute the base fee to protocol fee recipients
            marketMakingEngineConfiguration.distributeProtocolAssetReward(usdc, settlementBaseFeeUsd);
        }
    }

    function _convertUsdcToAssets(
        uint128 dexSwapStrategyId,
        address asset,
        UD60x18 usdcAmountX18,
        bytes memory path,
        address recipient
    )
        internal
        returns (uint256 assetOut)
    {
        // load the market making engine configuration storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // cache the usdc address
        address usdc = marketMakingEngineConfiguration.usdc;

        // revert if the amount is zero
        if (usdcAmountX18.isZero()) revert Errors.AssetAmountIsZero(usdc);

        // load the asset collateral data storage pointer
        Collateral.Data storage assetCollateralConfig = Collateral.load(usdc);

        // convert the stored assets decimals from 18 to the underlying token decimals
        uint256 usdcAmount = assetCollateralConfig.convertUd60x18ToTokenAmount(usdcAmountX18);

        // load the usdc collateral data storage pointer
        Collateral.Data storage usdcCollateral = Collateral.load(usdc);

        // cache the settlement base fee value using usdc's native decimals
        uint256 settlementBaseFeeUsd = usdcCollateral.convertUd60x18ToTokenAmount(
            ud60x18(marketMakingEngineConfiguration.settlementBaseFeeUsdX18)
        );

        // if there isn't enough usdc to convert the base fee, revert
        // NOTE: keepers must be configured to buy good chunks of usdc at minimum (e.g $500), as the settlement
        // base fee shouldn't be much greater than $1.
        if (usdcAmount < settlementBaseFeeUsd) {
            revert Errors.FailedToPaySettlementBaseFee();
        }

        // subtract fee
        usdcAmount -= settlementBaseFeeUsd;

        // if the asset being handled is usdc, simply add it to `usdcOut`
        if (asset == usdc) {
            assetOut = usdcAmount;
        } else {
            // loads the dex swap strategy data storage pointer
            DexSwapStrategy.Data storage dexSwapStrategy = DexSwapStrategy.loadExisting(dexSwapStrategyId);

            // approve the asset to be spent by the dex adapter contract
            IERC20(asset).approve(dexSwapStrategy.dexAdapter, usdcAmount);

            // verify if the swap should be input single or multihop
            if (path.length == 0) {
                // prepare the data for executing the swap
                SwapExactInputSinglePayload memory swapCallData = SwapExactInputSinglePayload({
                    tokenIn: usdc,
                    tokenOut: asset,
                    amountIn: usdcAmount,
                    recipient: recipient
                });

                // swap the credit deposit assets for USDC and store the output amount
                assetOut = dexSwapStrategy.executeSwapExactInputSingle(swapCallData);
            } else {
                // prepare the data for executing the swap
                SwapExactInputPayload memory swapCallData = SwapExactInputPayload({
                    path: path,
                    tokenIn: usdc,
                    tokenOut: asset,
                    amountIn: usdcAmount,
                    recipient: recipient
                });

                // swap the credit deposit assets for USDC and store the output amount
                assetOut = dexSwapStrategy.executeSwapExactInput(swapCallData);
            }

            // distribute the base fee to protocol fee recipients
            marketMakingEngineConfiguration.distributeProtocolAssetReward(usdc, settlementBaseFeeUsd);
        }
    }
}
