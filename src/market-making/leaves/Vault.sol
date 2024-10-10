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
/// + requested usdz.
/// This means if the engine fails to report the unrealized debt properly, its users will unexpectedly and unfairly be
/// deleveraged.
/// NOTE: We only take into account positive debt in order to prevent a malicious engine of reporting a large fake
/// credit, harming LPs.
/// The MM engine protects LPs by taking into account the requested USDz.
/// @dev Vault's debt for credit delegation purposes = unrealized debt of each market (Market::getTotalDebt or
/// market unrealized debt) +
/// unsettledRealizedDebtUsd (comes from each market's realized debt) + settledRealizedDebtUsd.
/// NOTE: each market's realized debt must always be distributed as unsettledRealizedDebt to vaults following the Debt
/// Distribution System.
/// @dev Vault's debt for asset settlement purposes = unsettledRealizedDebtUsd + settledRealizedDebtUsd
/// @dev A swap adds `settledRealizedDebt` but subtracts `unsettledRealizedDebt`. The Vault earns a swap fee for the
/// inconvenience, allocated as additional WETH staking rewards.2
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
        uint128 vaultId;
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

    /// @dev We use a `uint256` array because the vaults ids are stored at a `EnumerableSet.UintSet`.
    // TODO: mby move the loops to its own functions for better composability / testability
    function updateVaultsCreditDelegation(uint256[] memory vaultsIds, uint128 marketId) internal {
        for (uint256 i; i < vaultsIds.length; i++) {
            // uint256 -> uint128
            uint128 vaultId = vaultsIds[i].toUint128();
            // load the vault storage pointer
            Data storage self = load(vaultId);

            // prepare to `mstore` the vault's total unrealized and realized debt changes coming from each connected
            // market
            SD59x18 vaultTotalUnrealizedDebtChangeUsdX18;
            SD59x18 vaultTotalRealizedDebtChangeUsdX18;

            // loads the connected markets storage pointer by taking the ast configured market ids uint set
            EnumerableSet.UintSet storage connectedMarkets = self.connectedMarkets[self.connectedMarkets.length];

            // cache the connected markets ids to avoid multiple storage reads, as we're going to loop over them twice
            uint128[] memory connectedMarketsIdsCached = new uint128[](connectedMarkets.length());

            // iterate over each connected market id and distribute its debt so we can have the latest credit
            // delegation of the vault id being iterated to the provided `marketId`
            for (uint256 j; j < connectedMarketsIdsCached.length; j++) {
                // update the markets ids cache and load the market storage pointer
                connectedMarketsIdsCached[j] = connectedMarkets.at(j).toUint128();
                uint128 connectedMarketId = connectedMarketsIdsCached[j];
                Market.Data storage market = Market.load(connectedMarketId);

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

                if (unrealizedDebtChangeUsdX18.isZero() && realizedDebtChangeUsdX18.isZero()) {
                    continue;
                }

                // add the vault's share of the market's unrealized and realized debt to the cached values which
                // will update the vault's storage once this loop ends.
                vaultTotalUnrealizedDebtChangeUsdX18 =
                    vaultTotalUnrealizedDebtChangeUsdX18.add(unrealizedDebtChangeUsdX18);
                vaultTotalRealizedDebtChangeUsdX18 = vaultTotalRealizedDebtChangeUsdX18.add(realizedDebtChangeUsdX18);

                creditDelegation.updateVaultLastDistributedDebt(marketUnrealizedDebtUsdX18, marketRealizedDebtUsdX18);
            }

            // updates the vault's stored unrealized debt distributed from markets
            self.marketsUnrealizedDebtUsd = sd59x18(self.marketsUnrealizedDebtUsd).add(
                vaultTotalUnrealizedDebtChangeUsdX18
            ).intoInt256().toInt128();
            // updates the vault's stored unsettled realized debt distributed from markets
            self.unsettledRealizedDebtUsd =
                sd59x18(self.unsettledRealizedDebtUsd).add(vaultTotalRealizedDebtChangeUsdX18).intoInt256().toInt128();

            // loop over each connected market id that has been cached once again in order to update this vault's
            // credit delegations
            for (uint256 j; j < connectedMarketsIdsCached.length; j++) {
                // loads the memory cached market id
                uint128 connectedMarketId = connectedMarketsIdsCached[j];

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
}
