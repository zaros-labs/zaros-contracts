//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Zaros dependencies
import { CollateralConfig } from "./CollateralConfig.sol";
import { Distribution } from "./Distribution.sol";
import { Market } from "./Market.sol";
import { MarketConfiguration } from "./MarketConfiguration.sol";
import { Vault } from "./Vault.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO, UNIT as UD_UNIT, MAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

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
        uint128 minLiquidityRatio;
        uint128 totalMarketsWeights;
        Distribution.Data vaultsDebtDistribution;
        int128 totalVaultDebts;
        MarketConfiguration.Data[] marketConfigurations;
        mapping(address => Vault.Data) vaults;
    }

    /**
     * @dev Returns the pool stored at the specified pool id.
     */
    function load() internal pure returns (Data storage marketManager) {
        bytes32 s = _MARKET_MANAGER_SLOT;
        assembly {
            marketManager.slot := s
        }
    }

    function distributeDebtToVaults(Data storage self, address optionalCollateralType) internal {
        SD59x18 cumulativePendingDebt = SD_ZERO;
        for (uint256 i = 0; i < self.marketConfigurations.length; i++) {
            Market.Data storage market = Market.load(self.marketConfigurations[i].marketAddress);
            cumulativePendingDebt = cumulativePendingDebt.add(sd59x18(market.pendingDebt));
        }

        self.totalVaultDebts = sd59x18(self.totalVaultDebts).add(cumulativePendingDebt).intoInt256().toInt128();
        self.vaultsDebtDistribution.distributeValue(cumulativePendingDebt);

        if (optionalCollateralType != address(0)) {
            bytes32 actorId = bytes32(uint256(uint160(optionalCollateralType)));
            self.vaults[optionalCollateralType].distributeDebtToAccounts(
                self.vaultsDebtDistribution.accumulateActor(actorId)
            );
        }
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
        address marketAddress,
        UD60x18 minLiquidityRatio,
        SD59x18 debtPerShare
    )
        internal
        view
        returns (SD59x18)
    {
        Market.Data storage market = Market.load(marketAddress);
        SD59x18 valuePerShare = market.getDebtPerCredit();
        UD60x18 margin = minLiquidityRatio.isZero() ? UD_UNIT : UD_UNIT.div(minLiquidityRatio);

        return valuePerShare.add(margin.intoSD59x18()).sub(debtPerShare);
    }

    function recalculateVaultCollateral(
        Data storage self,
        address collateralType
    )
        internal
        returns (UD60x18 collateralPrice)
    {
        // Get the latest collateral price.
        collateralPrice = CollateralConfig.load(collateralType).getCollateralPrice();

        // Changes in price update the corresponding vault's total collateral value as well as its liquidity (collateral
        // - debt).
        UD60x18 totalCollateralValue = self.vaults[collateralType].currentCreditCapacity(collateralPrice);

        // Update the vault's shares in its debt distribution, according to the total value of its collateral.
        self.vaultsDebtDistribution.setActorShares(bytes32(uint256(uint160(collateralType))), totalCollateralValue);
        syncMarkets(self);
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
        returns (SD59x18 debt)
    {
        distributeDebtToVaults(self, collateralType);
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

    function syncMarkets(Data storage self) internal {
        UD60x18 totalMarketsWeights = ud60x18(self.totalMarketsWeights);
        if (totalMarketsWeights.isZero()) {
            return;
        }

        UD60x18 totalVaultsCreditCapacity = ud60x18(self.vaultsDebtDistribution.totalShares);
        SD59x18 debtPerCredit = totalVaultsCreditCapacity.isZero()
            ? SD_ZERO
            : sd59x18(self.totalVaultDebts).div(totalVaultsCreditCapacity.intoSD59x18());

        for (uint256 i = 0; i < self.marketConfigurations.length; i++) {
            MarketConfiguration.Data storage marketConfiguration = self.marketConfigurations[i];
            UD60x18 marketWeight = ud60x18(marketConfiguration.weight);
            UD60x18 marketCreditCapacity = totalVaultsCreditCapacity.mul(marketWeight).div(totalMarketsWeights);

            Market.Data storage market = Market.load(marketConfiguration.marketAddress);
            market.distributeDebt();
            market.creditCapacity = marketCreditCapacity.intoUint128();
        }
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
        SD59x18 vaultDebt = currentVaultDebt(self, collateralType);
        (, UD60x18 collateralValue) = currentVaultCollateral(self, collateralType);

        return vaultDebt.gt(SD_ZERO) ? collateralValue.div(vaultDebt.intoUD60x18()) : UD_ZERO;
    }

    /**
     * @dev Finds a connected market whose credit capacity has reached its locked limit.
     *
     * Note: Returns market zero (null market) if none is found.
     */
    function findMarketWithCapacityLocked(Data storage self) internal view returns (Market.Data storage lockedMarket) {
        for (uint256 i = 0; i < self.marketConfigurations.length; i++) {
            Market.Data storage market = Market.load(self.marketConfigurations[i].marketAddress);

            if (market.isCapacityLocked()) {
                return market;
            }
        }

        // Market zero = null market.
        return Market.load(address(0));
    }

    function getRequiredMinDelegationTime(Data storage self) internal view returns (uint32 requiredMinDelegateTime) {
        for (uint256 i = 0; i < self.marketConfigurations.length; i++) {
            uint32 marketMinDelegateTime = Market.load(self.marketConfigurations[i].marketAddress).minDelegateTime;

            if (marketMinDelegateTime > requiredMinDelegateTime) {
                requiredMinDelegateTime = marketMinDelegateTime;
            }
        }

        return MAX_MIN_DELEGATE_TIME < requiredMinDelegateTime ? MAX_MIN_DELEGATE_TIME : requiredMinDelegateTime;
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
        returns (UD60x18 collateralAmount, UD60x18 collateralValue)
    {
        UD60x18 collateralPrice = CollateralConfig.load(collateralType).getCollateralPrice();

        collateralAmount = self.vaults[collateralType].currentCollateral();
        collateralValue = collateralPrice.mul(collateralAmount);
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
        returns (UD60x18 collateralAmount, UD60x18 collateralValue)
    {
        UD60x18 collateralPrice = CollateralConfig.load(collateralType).getCollateralPrice();

        collateralAmount = self.vaults[collateralType].currentAccountCollateral(accountId);
        collateralValue = collateralPrice.mul(collateralAmount);
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
        SD59x18 positionDebt = updateAccountDebt(self, collateralType, accountId);
        if (positionDebt.lte(SD_ZERO)) {
            return MAX_UD60x18;
        }

        (, UD60x18 positionCollateralValue) = currentAccountCollateral(self, collateralType, accountId);

        return positionCollateralValue.div(positionDebt.intoUD60x18());
    }

    function requireMinDelegationTimeElapsed(Data storage self, uint64 lastDelegationTime) internal view {
        uint32 requiredMinDelegationTime = getRequiredMinDelegationTime(self);
        if (block.timestamp < lastDelegationTime + requiredMinDelegationTime) {
            revert Zaros_MarketManager_MinDelegationTimeoutPending(
                uint32(lastDelegationTime + requiredMinDelegationTime - block.timestamp)
            );
        }
    }
}
