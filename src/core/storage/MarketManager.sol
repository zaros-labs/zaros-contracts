//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

// Zaros dependencies
import { CollateralConfig } from "./CollateralConfig.sol";
import { Distribution } from "./Distribution.sol";
import { Market } from "./Market.sol";
import { MarketConfiguration } from "./MarketConfiguration.sol";
import { Vault } from "./Vault.sol";
import { AccessError } from "../../utils/Errors.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO, UNIT as UD_UNIT, MAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

struct Market {
        /**
         * @dev Address for the external contract that implements the `IMarket` interface, which this Market objects
         * connects to.
         *
         * Note: This object is how the system tracks the market. The actual market is external to the system, i.e. its
         * own contract.
         */
        address marketAddress;
        /**
         * @dev Issuance can be seen as how much USD the Market "has issued", printed, or has asked the system to mint
         * on its behalf.
         *
         * More precisely it can be seen as the net difference between the USD burnt and the USD minted by the market.
         *
         * More issuance means that the market owes more USD to the system.
         *
         * A market burns USD when users deposit it in exchange for some asset that the market offers.
         * The Market object calls `MarketManager.depositUSD()`, which burns the USD, and decreases its issuance.
         *
         * A market mints USD when users return the asset that the market offered and thus withdraw their USD.
         * The Market object calls `MarketManager.withdrawUSD()`, which mints the USD, and increases its issuance.
         *
         * Instead of burning, the Market object could transfer USD to and from the MarketManager, but minting and
         * burning takes the USD out of circulation, which doesn't affect `totalSupply`, thus simplifying accounting.
         *
         * How much USD a market can mint depends on how much credit capacity is given to the market by the pools that
         * support it, and reflected in `Market.capacity`.
         *
         */
        int128 netIssuanceD18;
        /**
         * @dev The total amount of USD that the market could withdraw if it were to immediately unwrap all its
         * positions.
         *
         * The Market's credit capacity increases when the market burns USD, i.e. when it deposits USD in the
         * MarketManager.
         *
         * It decreases when the market mints USD, i.e. when it withdraws USD from the MarketManager.
         *
         * The Market's credit capacity also depends on how much credit is given to it by the pools that support it.
         *
         * The Market's credit capacity also has a dependency on the external market reported debt as it will respond to
         * that debt (and hence change the credit capacity if it increases or decreases)
         *
         * The credit capacity can go negative if all of the collateral provided by pools is exhausted, and there is
         * market provided collateral available to consume. in this case, the debt is still being
         * appropriately assigned, but the market has a dynamic cap based on deposited collateral types.
         *
         */
        int128 creditCapacityD18;
        /**
         * @dev The amount of debt the pool has which hasn't been passed down the debt distribution chain yet.
         */
        uint128 pendingDebtD18;
        /**
         * @dev The total balance that the market had the last time that its debt was distributed.
         *
         * A Market's debt is distributed when the reported debt of its associated external market is rolled into the
         * pools that provide credit capacity to it.
         */
        int128 lastDistributedMarketBalanceD18;
        /**
         * @dev Market-specific override of the minimum liquidity ratio
         */
        uint256 minLiquidityRatioD18;
        uint32 minDelegateTime;
}

// import "./Config.sol";

/**
 * @title Aggregates collateral from multiple users in order to provide liquidity to a configurable set of markets.
 *
 * The set of markets is configured as an array of MarketConfiguration objects, where the weight of the market can be
 * specified. This weight, and the aggregated total weight of all the configured markets, determines how much collateral
 * from the pool each market has, as well as in what proportion the market passes on debt to the pool and thus to all
 * its users.
 *
 * The pool tracks the collateral provided by users using an array of Vaults objects, for which there will be one per
 * collateral type. Each vault tracks how much collateral each user has delegated to this pool, how much debt the user
 * has because of minting USD, as well as how much corresponding debt the pool has passed on to the user.
 */
library MarketManager {
    using CollateralConfig for CollateralConfig.Data;
    using Distribution for Distribution.Data;
    using Market for Market.Data;
    using SafeCast for int256;
    using Vault for Vault.Data;

    /**
     * @dev Thrown when min delegation time for a market connected to the pool has not elapsed
     */
    error Zaros_MarketManager_MinDelegationTimeoutPending(uint32 timeRemaining);

    bytes32 private constant _MARKET_MANAGER_SLOT = keccak256(abi.encodePacked("fi.zaros.core.MarketManager"));
    uint32 private constant MAX_MIN_DELEGATE_TIME = 30 days;

    struct Data {
        /**
         * @dev Sum of all market weights.
         *
         * Market weights are tracked in `MarketConfiguration.weight`, one for each market. The ratio of each market's
         * `weight` to the pool's `totalWeights` determines the pro-rata share of the market to the pool's total
         * liquidity.
         *
         * Reciprocally, this pro-rata share also determines how much the pool is exposed to each market's debt.
         */
        uint128 totalWeightsD18;
        /**
         * @dev Accumulated cache value of all vault collateral debts
         */
        int128 totalVaultDebtsD18;
        /**
         * @dev Array of markets connected to this pool, and their configurations. I.e. weight, etc.
         *
         * See totalWeights.
         */
        MarketConfiguration.Data[] marketConfigurations;
        /**
         * @dev A pool's debt distribution connects pools to the debt distribution chain, i.e. vaults and markets. Vaults
         * are actors in the pool's debt distribution, where the amount of shares they possess depends on the amount of
         * collateral each vault delegates to the pool.
         *
         * The debt distribution chain will move debt from markets into this pools, and then from pools to vaults.
         *
         * Actors: Vaults.
         * Shares: USD value, proportional to the amount of collateral that the vault delegates to the pool.
         * Value per share: Debt per dollar of collateral. Depends on aggregated debt of connected markets.
         *
         */
        Distribution.Data vaultsDebtDistribution;
        /**
         * @dev Reference to all the vaults that provide liquidity to this pool.
         *
         * Each collateral type will have its own vault, specific to this pool. I.e. if two pools both use SNX
         * collateral, each will have its own SNX vault.
         *
         * Vaults track user collateral and debt using a debt distribution, which is connected to the debt distribution
         * chain.
         */
        mapping(address => Vault.Data) vaults;
        /**
         * @dev Owner specified system-wide limiting factor that prevents markets from minting too much debt, similar to
         * the issuance ratio to a collateral type.
         *
         * Note: If zero, then this value defaults to 100%.
         */
        uint256 minLiquidityRatioD18;
        uint64 lastConfigurationTime;
    }

    /**
     * @dev Returns the pool stored at the specified pool id.
     */
    function load(uint128 id) internal pure returns (Data storage marketManager) {
        bytes32 s = _MARKET_MANAGER_SLOT;
        assembly {
            pool.slot := s
        }
    }

    /**
     * @dev Ticker function that updates the debt distribution chain downwards, from markets into the pool, according to
     * each market's weight.
     *
     * It updates the chain by performing the se actions:
     * - Splits the pool's total liquidity of the pool into each market, pro-rata. The amount of shares that the pool
     * has on each market depends on how much liquidity the pool provides to the market.
     * - Accumulates the change in debt value from each market into the pools own vault debt distribution's value per
     * share.
     */
    function distributeDebtToVaults(Data storage self) internal {
        UD60x18 totalWeightsD18 = ud60x18(self.totalWeightsD18);

        if (totalWeightsD18.isZero()) {
            return; // Nothing to rebalance.
        }

        // Read from storage once, before entering the loop below.
        // These values should not change while iterating through each market.
        UD60x18 totalCreditCapacityD18 = ud60x18(self.vaultsDebtDistribution.totalSharesD18);
        SD59x18 debtPerShareD18 = totalCreditCapacityD18.gt(UD_ZERO)
            ? sd59x18(self.totalVaultDebtsD18).div(totalCreditCapacityD18.intoSD59x18())
            : SD_ZERO;

        SD59x18 cumulativeDebtChangeD18 = SD_ZERO;

        UD60x18 systemMinLiquidityRatioD18 = ud60x18(self.minLiquidityRatioD18);

        // Loop through the pool's markets, applying market weights, and tracking how this changes the amount of debt
        // that this pool is responsible for.
        // This debt extracted from markets is then applied to the pool's vault debt distribution, which thus exposes
        // debt to the pool's vaults.
        for (uint256 i = 0; i < self.marketConfigurations.length; i++) {
            MarketConfiguration.Data storage marketConfiguration = self.marketConfigurations[i];

            UD60x18 weightD18 = ud60x18(marketConfiguration.weightD18);

            // Calculate each market's pro-rata USD liquidity.
            // Note: the factor `(weight / totalWeights)` is not deduped in the operations below to maintain numeric
            // precision.

            UD60x18 marketCreditCapacityD18 = totalCreditCapacityD18.mul(weightD18).div(totalWeightsD18);

            Market.Data storage marketData = Market.load(marketConfiguration.marketId);

            // Use market-specific minimum liquidity ratio if set, otherwise use system default.
            UD60x18 minLiquidityRatioD18 = marketData.minLiquidityRatioD18 > 0
                ? ud60x18(marketData.minLiquidityRatioD18)
                : systemMinLiquidityRatioD18;

            // Contain the pool imposed market's maximum debt share value.
            // Imposed by system.
            SD59x18 effectiveMaxShareValueD18 =
                getSystemMaxValuePerShare(marketData.id, minLiquidityRatioD18, debtPerShareD18);
            // Imposed by pool.
            SD59x18 configuredMaxShareValueD18 = sd59x18(marketConfiguration.maxDebtShareValueD18);
            effectiveMaxShareValueD18 = effectiveMaxShareValueD18.lt(configuredMaxShareValueD18)
                ? effectiveMaxShareValueD18
                : configuredMaxShareValueD18;

            // Update each market's corresponding credit capacity.
            // The returned value represents how much the market's debt changed after changing the shares of this pool
            // actor, which is aggregated to later be passed on the pools debt distribution.
            cumulativeDebtChangeD18 = cumulativeDebtChangeD18.add(
                Market.rebalancePools(
                    marketConfiguration.marketId, self.id, effectiveMaxShareValueD18, marketCreditCapacityD18
                )
            );
        }

        // Passes on the accumulated debt changes from the markets, into the pool, so that vaults can later access this
        // debt.
        // self.vaultsDebtDistribution.distributeValue(cumulativeDebtChangeD18);
    }

    /**
     * @dev Determines the resulting maximum value per share for a market, according to a system-wide minimum liquidity
     * ratio. This prevents markets from assigning more debt to pools than they have collateral to cover.
     *
     * Note: There is a market-wide fail safe for each market at `MarketConfiguration.maxDebtShareValue`. The lower of
     * the two values should be used.
     *
     * See `SystemPoolConfiguration.minLiquidityRatio`.
     */
    function getSystemMaxValuePerShare(
        uint128 marketId,
        UD60x18 minLiquidityRatioD18,
        SD59x18 debtPerShareD18
    )
        internal
        view
        returns (SD59x18)
    {
        // Retrieve the current value per share of the market.
        Market.Data storage marketData = Market.load(marketId);
        SD59x18 valuePerShareD18 = marketData.poolsDebtDistribution.getValuePerShare();

        // Calculate the margin of debt that the market would incur if it hit the system wide limit.
        UD60x18 marginD18 = minLiquidityRatioD18.isZero() ? UD_UNIT : UD_UNIT.div(minLiquidityRatioD18);

        // The resulting maximum value per share is the distribution's value per share,
        // plus the margin to hit the limit, minus the current debt per share.
        return valuePerShareD18.add(marginD18.intoSD59x18()).sub(debtPerShareD18);
    }

    /**
     * @dev Ticker function that updates the debt distribution chain for a specific collateral type downwards, from the
     * pool into the corresponding the vault, according to changes in the collateral's price.
     *
     * It updates the chain by performing these actions:
     * - Collects the latest price of the corresponding collateral and updates the vault's liquidity.
     * - Updates the vaults shares in the pool's debt distribution, according to the collateral provided by the vault.
     * - Updates the value per share of the vault's debt distribution.
     */
    function recalculateVaultCollateral(
        Data storage self,
        address collateralType
    )
        internal
        returns (UD60x18 collateralPriceD18)
    {
        // Update each market's pro-rata liquidity and collect accumulated debt into the pool's debt distribution.
        distributeDebtToVaults(self);

        // Transfer the debt change from the pool into the vault.
        bytes32 actorId = collateralType.toBytes32();
        self.vaults[collateralType].distributeDebtToAccounts(self.vaultsDebtDistribution.accumulateActor(actorId));

        // Get the latest collateral price.
        collateralPriceD18 = CollateralConfig.load(collateralType).getCollateralPrice();

        // Changes in price update the corresponding vault's total collateral value as well as its liquidity (collateral
        // - debt).
        (UD60x18 usdWeightD18,, SD59x18 deltaDebtD18) =
            self.vaults[collateralType].updateCreditCapacity(collateralPriceD18);

        // Update the vault's shares in the pool's debt distribution, according to the value of its collateral.
        self.vaultsDebtDistribution.setActorShares(actorId, usdWeightD18);

        // Accumulate the change in total liquidity, from the vault, into the pool.
        self.totalVaultDebtsD18 = sd59x18(self.totalVaultDebtsD18).add(deltaDebtD18).intoInt256().toInt128();

        // Distribute debt again because the market credit capacity may have changed, so we should ensure the vaults
        // have the most up to date capacities
        distributeDebtToVaults(self);
    }

    /**
     * @dev Updates the debt distribution chain for this pool, and consolidates the given account's debt.
     */
    function updateAccountDebt(
        Data storage self,
        address collateralType,
        uint128 accountId
    )
        internal
        returns (SD59x18 debtD18)
    {
        recalculateVaultCollateral(self, collateralType);

        return self.vaults[collateralType].consolidateAccountDebt(accountId);
    }

    /**
     * @dev Clears all vault data for the specified collateral type.
     */
    function resetVault(Data storage self, address collateralType) internal {
        // Creates a new epoch in the vault, effectively zeroing out all values.
        self.vaults[collateralType].reset();

        // Ensure that the vault's values update the debt distribution chain.
        recalculateVaultCollateral(self, collateralType);
    }

    /**
     * @dev Calculates the collateralization ratio of the vault that tracks the given collateral type.
     *
     * The c-ratio is the vault's share of the total debt of the pool, divided by the collateral it delegates to the
     * pool.
     *
     * Note: This is not a view function. It updates the debt distribution chain before performing any calculations.
     */
    function currentVaultCollateralRatio(Data storage self, address collateralType) internal returns (UD60x18) {
        SD59x18 vaultDebtD18 = currentVaultDebt(self, collateralType);
        (, UD60x18 collateralValueD18) = currentVaultCollateral(self, collateralType);

        return vaultDebtD18.gt(UD_ZERO) ? collateralValueD18.div(vaultDebtD18.intoUD60x18()) : UD_ZERO;
    }

    /**
     * @dev Finds a connected market whose credit capacity has reached its locked limit.
     *
     * Note: Returns market zero (null market) if none is found.
     */
    function findMarketWithCapacityLocked(Data storage self) internal view returns (Market.Data storage lockedMarket) {
        for (uint256 i = 0; i < self.marketConfigurations.length; i++) {
            Market.Data storage market = Market.load(self.marketConfigurations[i].marketId);

            if (market.isCapacityLocked()) {
                return market;
            }
        }

        // Market zero = null market.
        return Market.load(0);
    }

    function getRequiredMinDelegationTime(Data storage self) internal view returns (uint32 requiredMinDelegateTime) {
        for (uint256 i = 0; i < self.marketConfigurations.length; i++) {
            uint32 marketMinDelegateTime = Market.load(self.marketConfigurations[i].marketId).minDelegateTime;

            if (marketMinDelegateTime > requiredMinDelegateTime) {
                requiredMinDelegateTime = marketMinDelegateTime;
            }
        }

        return MAX_MIN_DELEGATE_TIME < requiredMinDelegateTime ? maxMinDelegateTime : requiredMinDelegateTime;
    }

    /**
     * @dev Returns the debt of the vault that tracks the given collateral type.
     *
     * The vault's debt is the vault's share of the total debt of the pool, or its share of the total debt of the
     * markets connected to the pool. The size of this share depends on how much collateral the pool provides to the
     * pool.
     *
     * Note: This is not a view function. It updates the debt distribution chain before performing any calculations.
     */
    function currentVaultDebt(Data storage self, address collateralType) internal returns (SD59x18) {
        recalculateVaultCollateral(self, collateralType);

        return self.vaults[collateralType].currentDebt();
    }

    /**
     * @dev Returns the total amount and value of the specified collateral delegated to this pool.
     */
    function currentVaultCollateral(
        Data storage self,
        address collateralType
    )
        internal
        view
        returns (UD60x18 collateralAmountD18, UD60x18 collateralValueD18)
    {
        UD60x18 collateralPriceD18 = CollateralConfig.load(collateralType).getCollateralPrice();

        collateralAmountD18 = self.vaults[collateralType].currentCollateral();
        collateralValueD18 = collateralPriceD18.mul(collateralAmountD18);
    }

    /**
     * @dev Returns the amount and value of collateral that the specified account has delegated to this pool.
     */
    function currentAccountCollateral(
        Data storage self,
        address collateralType,
        uint128 accountId
    )
        internal
        view
        returns (UD60x18 collateralAmountD18, UD60x18 collateralValueD18)
    {
        UD60x18 collateralPriceD18 = CollateralConfig.load(collateralType).getCollateralPrice();

        collateralAmountD18 = self.vaults[collateralType].currentAccountCollateral(accountId);
        collateralValueD18 = collateralPriceD18.mul(collateralAmountD18);
    }

    /**
     * @dev Returns the specified account's collateralization ratio (collateral / debt).
     * @dev If the account's debt is negative or zero, returns an "infinite" c-ratio.
     */
    function currentAccountCollateralRatio(
        Data storage self,
        address collateralType,
        uint128 accountId
    )
        internal
        returns (UD60x18)
    {
        SD59x18 positionDebtD18 = updateAccountDebt(self, collateralType, accountId);
        if (positionDebtD18.le(SD_ZERO)) {
            return MAX_UD60x18;
        }

        (, UD60x18 positionCollateralValueD18) = currentAccountCollateral(self, collateralType, accountId);

        return positionCollateralValueD18.div(positionDebtD18.intoUD60x18());
    }

    function requireMinDelegationTimeElapsed(Data storage self, uint64 lastDelegationTime) internal view {
        uint32 requiredMinDelegationTime = getRequiredMinDelegationTime(self);
        if (block.timestamp < lastDelegationTime + requiredMinDelegationTime) {
            revert MinDelegationTimeoutPending(
                self.id,
                // solhint-disable-next-line numcast/safe-cast
                uint32(lastDelegationTime + requiredMinDelegationTime - block.timestamp)
            );
        }
    }
}
