// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Math } from "@zaros/utils/Math.sol";
import { Collateral } from "./Collateral.sol";
import { CreditDelegation } from "./CreditDelegation.sol";
import { Distribution } from "./Distribution.sol";
import { Market } from "@zaros/market-making/leaves/Market.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD60x18_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD59x18_ZERO } from "@prb-math/SD59x18.sol";

/// @dev Vault's debt for ADL determination purposes:
///  (unrealized debt > 0 ? unrealized debt : 0 || TODO: define this) + realized debt + unsettled debt + settled debt
/// + requested usdToken.
/// This means if the engine fails to report the unrealized debt properly, its users will unexpectedly and unfairly be
/// deleveraged.
/// NOTE: We only take into account positive debt in order to prevent a malicious engine of reporting a large fake
/// credit, harming LPs.
/// The MM engine protects LPs by taking into account the requested USD Token.
/// @dev Vault's debt for credit delegation purposes = unrealized debt of each market (Market::getTotalDebt or
/// market unrealized debt) +
/// unsettledRealizedDebtUsd (comes from each market's realized debt) + settledRealizedDebtUsd.
/// NOTE: each market's realized debt must always be distributed as unsettledRealizedDebt to vaults following the Debt
/// Distribution System.
/// @dev Vault's debt for asset settlement purposes = unsettledRealizedDebtUsd + settledRealizedDebtUsd
/// @dev A swap adds `settledRealizedDebt` but subtracts `unsettledRealizedDebt`. The Vault earns a swap fee for the
/// inconvenience, allocated as additional WETH staking rewards.2
// todo: next, update natspec here then work on the new usd tokens system and finalize by implementing the missing
// functions
// todo: see if we different service leaves from repository (or something else) leaves.
// Vault::recalculateVaultsCreditCapacity is a service function that should live in a service leaf.
// todo: create vault service and services directory, separating from leaf logic. See services internal notes
library Vault {
    using Collateral for Collateral.Data;
    using CreditDelegation for CreditDelegation.Data;
    using EnumerableSet for EnumerableSet.UintSet;
    using Market for Market.Data;
    using SafeCast for uint256;
    using SafeCast for int256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant VAULT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Vault")) - 1));

    /// @param id The vault identifier.
    /// @param totalDeposited The total amount of collateral assets deposited in the vault.
    /// @param depositCap The maximum amount of collateral assets that can be deposited in the vault.
    /// @param withdrawalDelay The delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @param lockedCreditRatio The configured ratio that determines how much of the vault's total assets can't be
    /// withdrawn according to the Vault's total debt, in order to secure the credit delegation system.
    /// @param marketsUnrealizedDebtUsd The total amount of unrealized debt coming from markets in USD.
    /// @param unsettledRealizedDebtUsd The total amount of unsettled debt in USD.
    /// @param settledRealizedDebtUsd The total amount of settled debt in USD.
    /// @param indexToken The index token address.
    /// @param collateral The collateral asset data.
    /// @param stakingFeeDistribution `actor`: Stakers, `shares`: Staked index tokens, `valuePerShare`: WETH fee
    /// earned per share.
    /// @param connectedMarkets The list of connected market ids. Whenever there's an update, a new
    /// `EnumerableSet.UintSet` is created.
    // TODO: update natspec here and connect a vault to an engine.
    struct Data {
        uint128 id;
        uint128 totalDeposited;
        uint128 totalCreditDelegationWeight;
        uint128 depositCap;
        uint128 withdrawalDelay;
        uint128 lockedCreditRatio;
        int128 marketsUnrealizedDebtUsd;
        int128 unsettledRealizedDebtUsd;
        int128 settledRealizedDebtUsd;
        address indexToken;
        address connectedEngine;
        Collateral.Data collateral;
        Distribution.Data stakingFeeDistribution;
        EnumerableSet.UintSet[] connectedMarkets;
    }

    /// @notice Loads a {Vault} namespace.
    /// @param vaultId The vault identifier.
    /// @return vault The loaded vault storage pointer.
    function load(uint128 vaultId) internal pure returns (Data storage vault) {
        bytes32 slot = keccak256(abi.encode(VAULT_LOCATION, vaultId));
        assembly {
            vault.slot := slot
        }
    }

    function getLockedCreditCapacityUsd(Data storage self) internal view returns (SD59x18) {
        return getTotalCreditCapacityUsd(self).mul(ud60x18(self.lockedCreditRatio).intoSD59x18());
    }

    function getTotalCreditCapacityUsd(Data storage self) internal view returns (SD59x18 vaultCreditCapacityUsdX18) {
        Collateral.Data storage collateral = self.collateral;
        // TODO: update self.totalDeposited to ERC4626::totalAssets
        UD60x18 totalAssetsUsdX18 = collateral.getPrice().mul(ud60x18(self.totalDeposited));

        vaultCreditCapacityUsdX18 = totalAssetsUsdX18.intoSD59x18().sub(sd59x18(self.unsettledRealizedDebtUsd));
    }

    // TODO: see if this function will be used elsewhere or if we can turn it into a private function for better
    // testability / visibility
    /// @notice Recalculates the latest debt of each market connected to a vault, distributing its total debt to it.
    /// @param self The vault storage pointer.
    /// @param connectedMarketsIdsCache The cached connected markets ids.
    /// @param shouldRehydrateCache Whether the connected markets ids cache should be rehydrated or not.
    /// @return rehydratedConnectedMarketsIdsCache The potentially rehydrated connected markets ids cache.
    /// @return vaultTotalUnrealizedDebtChangeUsdX18 The vault's total unrealized debt change in USD.
    /// @return vaultTotalRealizedDebtChangeUsdX18 The vault's total realized debt change in USD.
    function recalculateConnectedMarketsDebt(
        Data storage self,
        uint128[] memory connectedMarketsIdsCache,
        bool shouldRehydrateCache
    )
        internal
        returns (
            uint128[] memory rehydratedConnectedMarketsIdsCache,
            SD59x18 vaultTotalUnrealizedDebtChangeUsdX18,
            SD59x18 vaultTotalRealizedDebtChangeUsdX18
        )
    {
        // cache the vault id
        uint128 vaultId = self.id;
        // loads the connected markets storage pointer by taking the last configured market ids uint set
        EnumerableSet.UintSet storage connectedMarkets = self.connectedMarkets[self.connectedMarkets.length];

        for (uint256 j; j < connectedMarketsIdsCache.length; j++) {
            if (shouldRehydrateCache) {
                rehydratedConnectedMarketsIdsCache[j] = connectedMarkets.at(j).toUint128();
            } else {
                rehydratedConnectedMarketsIdsCache[j] = connectedMarketsIdsCache[j];
            }
            // loads the memory cached market id
            uint128 connectedMarketId = connectedMarketsIdsCache[j];
            // loads the market storage pointer
            Market.Data storage market = Market.load(connectedMarketId);

            // prepare to store the market's unrealized debt and realized debt values
            SD59x18 marketUnrealizedDebtUsdX18;
            SD59x18 marketRealizedDebtUsdX18;

            // if the market has already had its debt distributed at the current block, we skip it
            if (market.isDistributionRequired()) {
                // first we cache the market's unrealized and realized debt
                marketUnrealizedDebtUsdX18 = market.getUnrealizedDebtUsd();
                marketRealizedDebtUsdX18 = market.getRealizedDebtUsd();

                // distribute the market's debt to its connected vaults
                market.distributeDebtToVaults(marketUnrealizedDebtUsdX18, marketRealizedDebtUsdX18);
            }

            // load the credit delegation to the given market id
            CreditDelegation.Data storage creditDelegation = CreditDelegation.load(vaultId, connectedMarketId);

            // accumulate the vault's associated debt change and returns the unrealized and realized debt changes
            // since the last distribution
            (SD59x18 unrealizedDebtChangeUsdX18, SD59x18 realizedDebtChangeUsdX18) = market.accumulateVaultDebt(
                vaultId,
                sd59x18(creditDelegation.lastVaultDistributedUnrealizedDebtUsd),
                sd59x18(creditDelegation.lastVaultDistributedRealizedDebtUsd)
            );

            // if there's been no change in neither the unrealized nor the realized debt, we can iterate to the next
            // market id
            if (unrealizedDebtChangeUsdX18.isZero() && realizedDebtChangeUsdX18.isZero()) {
                continue;
            }

            // add the vault's share of the market's unrealized and realized debt to the cached values which
            // will update the vault's storage once this loop ends.
            vaultTotalUnrealizedDebtChangeUsdX18 =
                vaultTotalUnrealizedDebtChangeUsdX18.add(unrealizedDebtChangeUsdX18);
            vaultTotalRealizedDebtChangeUsdX18 = vaultTotalRealizedDebtChangeUsdX18.add(realizedDebtChangeUsdX18);

            // updates the last distributed debt values to the vault's credit delegation to the given market id
            creditDelegation.updateVaultLastDistributedDebt(marketUnrealizedDebtUsdX18, marketRealizedDebtUsdX18);
        }
    }

    /// @dev We use a `uint256` array because a market's connected vaults ids are stored at a `EnumerableSet.UintSet`.
    // todo: benchmark worst, average and best case gas costs for this function
    /// @notice Recalculates the latest credit capacity of the provided vaults ids taking into account their latest
    /// assets and debt usd denonimated values.
    /// @param vaultsIds The array of vaults ids to recalculate the credit capacity.
    function recalculateVaultsCreditCapacity(uint256[] memory vaultsIds) internal {
        for (uint256 i; i < vaultsIds.length; i++) {
            // uint256 -> uint128
            uint128 vaultId = vaultsIds[i].toUint128();
            // load the vault storage pointer
            Data storage self = load(vaultId);

            // loads the connected markets storage pointer by taking the last configured market ids uint set
            EnumerableSet.UintSet storage connectedMarkets = self.connectedMarkets[self.connectedMarkets.length];

            // cache the connected markets ids to avoid multiple storage reads, as we're going to loop over them twice
            // at `recalculateConnectedMarketsDebt` and `updateCreditDelegations`
            uint128[] memory connectedMarketsIdsCache = new uint128[](connectedMarkets.length());

            // iterate over each connected market id and distribute its debt so we can have the latest credit
            // delegation of the vault id being iterated to the provided `marketId`
            (
                uint128[] memory updatedConnectedMarketsIdsCache,
                SD59x18 vaultTotalUnrealizedDebtChangeUsdX18,
                SD59x18 vaultTotalRealizedDebtChangeUsdX18
            ) = recalculateConnectedMarketsDebt(self, connectedMarketsIdsCache, true);

            // updates the vault's stored unrealized debt distributed from markets
            self.marketsUnrealizedDebtUsd = sd59x18(self.marketsUnrealizedDebtUsd).add(
                vaultTotalUnrealizedDebtChangeUsdX18
            ).intoInt256().toInt128();
            // updates the vault's stored unsettled realized debt distributed from markets
            self.unsettledRealizedDebtUsd =
                sd59x18(self.unsettledRealizedDebtUsd).add(vaultTotalRealizedDebtChangeUsdX18).intoInt256().toInt128();

            // update the vault's credit delegations
            updateCreditDelegations(self, updatedConnectedMarketsIdsCache, false);
        }
    }

    // todo: see if the `shouldRehydrateCache` parameter will be needed or not
    // TODO: see if this function will be used elsewhere or if we can turn it into a private function for better
    // testability / visibility
    // todo: we may need to remove the return value to save gas / remove if not needed
    /// @notice Updates the vault's credit delegations to its connected markets, using the provided cache of connected
    /// markets ids.
    /// @dev This function assumes that the connected markets ids cache is up to date with the stored markets ids. If
    /// this invariant resolves to false, the function will not work as expected.
    /// @param self The vault storage pointer.
    /// @param connectedMarketsIdsCache The cached connected markets ids.
    /// @param shouldRehydrateCache Whether the connected markets ids cache should be rehydrated or not.
    /// @return rehydratedConnectedMarketsIdsCache The potentially rehydrated connected markets ids cache.
    function updateCreditDelegations(
        Data storage self,
        uint128[] memory connectedMarketsIdsCache,
        bool shouldRehydrateCache
    )
        internal
        returns (uint128[] memory rehydratedConnectedMarketsIdsCache)
    {
        // cache the vault id
        uint128 vaultId = self.id;
        // loads the connected markets storage pointer by taking the last configured market ids uint set
        EnumerableSet.UintSet storage connectedMarkets = self.connectedMarkets[self.connectedMarkets.length];

        // loop over each connected market id that has been cached once again in order to update this vault's
        // credit delegations
        for (uint256 j; j < connectedMarketsIdsCache.length; j++) {
            // rehydrate the markets ids cache if needed
            if (shouldRehydrateCache) {
                rehydratedConnectedMarketsIdsCache[j] = connectedMarkets.at(j).toUint128();
            } else {
                rehydratedConnectedMarketsIdsCache[j] = connectedMarketsIdsCache[j];
            }

            // loads the memory cached market id
            uint128 connectedMarketId = rehydratedConnectedMarketsIdsCache[j];

            // load the credit delegation to the given market id
            CreditDelegation.Data storage creditDelegation = CreditDelegation.load(vaultId, connectedMarketId);

            // // get the latest credit delegation share of the vault's credit capacity
            UD60x18 creditDelegationShareX18 =
                ud60x18(creditDelegation.weight).div(ud60x18(self.totalCreditDelegationWeight));

            // caches the vault's total credit capacity
            SD59x18 vaultCreditCapacity = getTotalCreditCapacityUsd(self);

            // if the vault's credit capacity went to zero or below, we set its credit delegation to that market
            // to zero
            // TODO: think about the implications of this, as it might lead to markets going insolvent due and bad
            // debt generation as the vault's collateral value unexpectedly tanks and / or its total debt
            // increases.
            UD60x18 newCreditDelegationUsdX18 = vaultCreditCapacity.gt(SD59x18_ZERO)
                ? vaultCreditCapacity.intoUD60x18().mul(creditDelegationShareX18)
                : UD60x18_ZERO;

            // loads the market's storage pointer
            Market.Data storage market = Market.load(connectedMarketId);
            // updates the market's vaults debt distributions with this vault's new credit delegation, i.e updates
            // its shares of the market's vaults debt distributions
            market.updateVaultCreditDelegation(vaultId, newCreditDelegationUsdX18);
        }
    }
}
