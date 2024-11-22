// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Collateral } from "./Collateral.sol";
import { CreditDelegation } from "./CreditDelegation.sol";
import { Distribution } from "./Distribution.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Market } from "./Market.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { IERC4626 } from "@openzeppelin/interfaces/IERC4626.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD60x18_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD59x18_ZERO } from "@prb-math/SD59x18.sol";

/// @dev Vault's debt for ADL determination purposes:
///  unrealized debt + realized debt + unsettled debt + settled debt
/// This means if the engine fails to report the unrealized debt properly, its users will unexpectedly and unfairly be
/// deleveraged, and lps of vaults providing liquidity to that engine may be exploited by that bad implementation.
/// @dev Vault's debt for credit delegation purposes = unrealized debt of each market (Market::getTotalDebt or
/// market unrealized debt) +
/// unsettledRealizedDebtUsd (comes from each market's realized debt).
/// @dev NOTE: each market's realized debt must always be distributed as unsettledRealizedDebt to vaults following the
/// Debt Distribution System.
/// @dev Vault's debt for asset settlement purposes = unsettledRealizedDebtUsd
/// @dev A swap adds `settledRealizedDebt` but subtracts `unsettledRealizedDebt`. The Vault earns a swap fee for the
/// inconvenience, allocated as additional WETH staking rewards.2
/// TODO: we need to update the system's global debt during vault debt distribution triggers, will do so in a next PR
/// handling debt / credit settlement.
library Vault {
    using Collateral for Collateral.Data;
    using CreditDelegation for CreditDelegation.Data;
    using Distribution for Distribution.Data;
    using EnumerableSet for EnumerableSet.UintSet;
    using Market for Market.Data;
    using SafeCast for uint256;
    using SafeCast for int256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant VAULT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Vault")) - 1));

    /// @notice Emitted when a vault's credit capacity is updated at the `Vault::recalculateVaultsCreditCapacity`
    /// loop.
    /// @param vaultId The vault identifier.
    /// @param vaultUnrealizedDebtChangeUsd The vault's unrealized debt update during the recalculation.
    /// @param vaultRealizedDebtChangeUsd The vault's realized debt update during the recalculation.
    /// @param vaultNewCreditCapacityUsd The vault's new credit capacity after the recalculation of total debt and the
    /// USD adjusted value of its underlying assets.
    /// @dev The parameter above is adjusted by the configured collateral's credit ratio.
    event LogUpdateVaultCreditCapacity(
        uint128 indexed vaultId,
        int256 vaultUnrealizedDebtChangeUsd,
        int256 vaultRealizedDebtChangeUsd,
        int256 vaultNewCreditCapacityUsd
    );

    /// @param id The vault identifier.
    /// @param totalCreditDelegationWeight The total amount of credit delegation weight in the vault.
    /// @param depositCap The maximum amount of collateral assets that can be deposited in the vault.
    /// @param withdrawalDelay The delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @param lockedCreditRatio The configured ratio that determines how much of the vault's total assets can't be
    /// withdrawn according to the Vault's total debt, in order to secure the credit delegation system.
    /// @param marketsUnrealizedDebtUsd The total amount of unrealized debt coming from markets in USD.
    /// @param unsettledRealizedDebtUsd The total amount of unsettled debt in USD.
    /// @param marketDepositedUsdc The total amount of credit deposits from markets that have been converted and
    /// distributed as USDC to vaults.
    /// @param indexToken The index token address.
    /// @param collateral The collateral asset data.
    /// @param stakingFeeDistribution `actor`: Stakers, `shares`: Staked index tokens, `valuePerShare`: WETH fee
    /// earned per share.
    /// todo: assert that when configuring the connected markets ids that they all belong to the same engine.
    /// todo: we may need to store the connected engine contract address.
    /// @param connectedMarkets The list of connected market ids. Whenever there's an update, a new
    /// `EnumerableSet.UintSet` is created.
    /// @param withdrawalRequestIdCounter Counter for user withdraw requiest ids
    struct Data {
        uint128 id;
        uint128 totalCreditDelegationWeight;
        uint128 depositCap;
        uint128 withdrawalDelay;
        uint128 lockedCreditRatio;
        int128 marketsUnrealizedDebtUsd;
        int128 unsettledRealizedDebtUsd;
        uint128 marketDepositedUsdc;
        address indexToken;
        bool isLive;
        Collateral.Data collateral;
        Distribution.Data wethRewardDistribution;
        EnumerableSet.UintSet[] connectedMarkets;
        mapping(address => uint128) withdrawalRequestIdCounter;
    }

    /// @notice Parameters required to create a new vault.
    /// @param vaultId The unique identifier for the vault to be created.
    /// @param depositCap The maximum amount of collateral assets that can be deposited in the vault.
    /// @param withdrawalDelay The delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @param indexToken The address of the index token used in the vault.
    /// @param collateral The collateral asset data associated with the vault.
    struct CreateParams {
        uint128 vaultId;
        uint128 depositCap;
        uint128 withdrawalDelay;
        address indexToken;
        Collateral.Data collateral;
    }

    /// @notice Parameters required to update an existing vault.
    /// @param vaultId The unique identifier for the vault to be updated.
    /// @param depositCap The new maximum amount of collateral assets that can be deposited in the vault.
    /// @param withdrawalDelay The new delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @param isLive The new status of the vault.
    struct UpdateParams {
        uint128 vaultId;
        uint128 depositCap;
        uint128 withdrawalDelay;
        bool isLive;
    }

    /// @notice Loads a {Vault} namespace.
    /// @param vaultId The vault identifier.
    /// @return vault The loaded vault storage pointer.
    // todo: add engine parameter
    function load(uint128 vaultId) internal pure returns (Data storage vault) {
        bytes32 slot = keccak256(abi.encode(VAULT_LOCATION, vaultId));
        assembly {
            vault.slot := slot
        }
    }

    /// @notice Loads a {Vault} namespace.
    /// @dev Invariants:
    /// The Vault MUST exist.
    /// @param vaultId The vault identifier.
    /// @return vault The loaded vault storage pointer.
    function loadExisting(uint128 vaultId) internal view returns (Data storage vault) {
        vault = load(vaultId);
        if (vault.id == 0) {
            revert Errors.VaultDoesNotExist(vaultId);
        }
        return vault;
    }

    /// @notice Loads a {Vault} namespace.
    /// @dev Invariants:
    /// The Vault MUST exist.
    /// The Vault MUST be live.
    /// @param vaultId The vault identifier.
    /// @return vault The loaded vault storage pointer.
    function loadLive(uint128 vaultId) internal view returns (Data storage vault) {
        vault = loadExisting(vaultId);

        if (!vault.isLive) {
            revert Errors.VaultIsDisabled(vaultId);
        }
    }

    /// @notice Returns the vault's minimum credit capacity allocated to the connected markets.
    /// @dev Prevents the vault's LPs from withdrawing more collateral than allowed, leading to potential liquidity
    /// issues to connected markets.
    /// @param self The vault storage pointer.
    function getLockedCreditCapacityUsd(Data storage self) internal view returns (SD59x18) {
        return getTotalCreditCapacityUsd(self).mul(ud60x18(self.lockedCreditRatio).intoSD59x18());
    }

    /// @notice Returns the vault's total credit capacity allocated to the connected markets.
    /// @dev The vault's total credit capacity is adjusted by its the credit ratio of its underlying collateral asset.
    /// @param self The vault storage pointer.
    /// @return vaultCreditCapacityUsdX18 The vault's total credit capacity in USD.
    function getTotalCreditCapacityUsd(Data storage self) internal view returns (SD59x18 vaultCreditCapacityUsdX18) {
        // load the collateral configuration storage pointer
        Collateral.Data storage collateral = self.collateral;

        // fetch the zlp vault's total assets amount
        UD60x18 totalAssetsX18 = ud60x18(IERC4626(collateral.asset).totalAssets());
        // calculate the total assets value in usd terms
        UD60x18 totalAssetsUsdX18 = collateral.getAdjustedPrice().mul(totalAssetsX18);

        // calculate the vault's credit capacity in usd terms
        vaultCreditCapacityUsdX18 = totalAssetsUsdX18.intoSD59x18().sub(sd59x18(self.unsettledRealizedDebtUsd));
    }

    /// @notice Returns the vault's total unsettled debt in USD, taking into account both the markets' unrealized
    /// debt, but yet to be settled.
    /// @dev Note that only the vault's share of the markets' realized debt is taken into consideration for debt /
    /// credit settlements.
    /// @param self The vault storage pointer.
    /// @return unsettledDebtUsdX18 The vault's total unsettled debt in USD.
    function getUnsettledDebt(Data storage self) internal view returns (SD59x18 unsettledDebtUsdX18) {
        unsettledDebtUsdX18 = sd59x18(self.unsettledRealizedDebtUsd).add(sd59x18(self.marketsUnrealizedDebtUsd));
    }

    // TODO: see if this function will be used elsewhere or if we can turn it into a private function for better
    // testability / visibility
    /// @notice Recalculates the latest debt of each market connected to a vault, distributing its total debt to it.
    /// @param self The vault storage pointer.
    /// @param connectedMarketsIdsCache The cached connected markets ids.
    /// @param shouldRehydrateCache Whether the connected markets ids cache should be rehydrated or not.
    /// @return rehydratedConnectedMarketsIdsCache The potentially rehydrated connected markets ids cache.
    /// @return vaultTotalWethRewardChangeX18 The vault's total WETH reward change.
    /// @return vaultTotalUnrealizedDebtChangeUsdX18 The vault's total unrealized debt change in USD.
    /// @return vaultTotalRealizedDebtChangeUsdX18 The vault's total realized debt change in USD.
    function recalculateConnectedMarketsDebtAndReward(
        Data storage self,
        uint128[] memory connectedMarketsIdsCache,
        bool shouldRehydrateCache
    )
        internal
        returns (
            uint128[] memory rehydratedConnectedMarketsIdsCache,
            UD60x18 vaultTotalWethRewardChangeX18,
            SD59x18 vaultTotalUnrealizedDebtChangeUsdX18,
            SD59x18 vaultTotalRealizedDebtChangeUsdX18
        )
    {
        rehydratedConnectedMarketsIdsCache = new uint128[](connectedMarketsIdsCache.length);

        // cache the vault id
        uint128 vaultId = self.id;

        // make sure there are markets connected to the vault
        if (self.connectedMarkets.length == 0) revert Errors.NoMarketsConnectedToVault(vaultId);

        // loads the connected markets storage pointer by taking the last configured market ids uint set
        EnumerableSet.UintSet storage connectedMarkets = self.connectedMarkets[self.connectedMarkets.length - 1];

        // TODO: update j to i
        for (uint256 j; j < connectedMarketsIdsCache.length; j++) {
            if (shouldRehydrateCache) {
                rehydratedConnectedMarketsIdsCache[j] = connectedMarkets.at(j).toUint128();
            } else {
                rehydratedConnectedMarketsIdsCache[j] = connectedMarketsIdsCache[j];
            }

            // loads the memory cached market id
            uint128 connectedMarketId = rehydratedConnectedMarketsIdsCache[j];
            // loads the market storage pointer
            Market.Data storage market = Market.load(connectedMarketId);

            // first we cache the market's unrealized and realized debt
            SD59x18 marketUnrealizedDebtUsdX18 = market.getUnrealizedDebtUsd();

            if (marketUnrealizedDebtUsdX18.isZero()) {
                continue;
            }

            // get the latest realized debt of the market while potentially saving gas
            SD59x18 marketRealizedDebtUsdX18 =
                market.isRealizedDebtUpdateRequired() ? market.updateRealizedDebt() : market.getRealizedDebtUsd();

            // distribute the market's debt to its connected vaults
            market.distributeDebtToVaults(marketUnrealizedDebtUsdX18, marketRealizedDebtUsdX18);

            // load the credit delegation to the given market id
            CreditDelegation.Data storage creditDelegation = CreditDelegation.load(vaultId, connectedMarketId);

            // accumulate the vault's associated debt and weth reward change and returns the unrealized and realized
            // debt changes since the last distribution
            (UD60x18 wethRewardChangeX18, SD59x18 unrealizedDebtChangeUsdX18, SD59x18 realizedDebtChangeUsdX18) =
            market.accumulateVaultDebtAndReward(
                vaultId,
                ud60x18(creditDelegation.lastVaultDistributedWethRewardPerShare),
                sd59x18(creditDelegation.lastVaultDistributedUnrealizedDebtUsdPerShare),
                sd59x18(creditDelegation.lastVaultDistributedRealizedDebtUsdPerShare)
            );

            // if there's been no change in neither the unrealized nor the realized debt, we can iterate to the next
            // market id
            if (
                unrealizedDebtChangeUsdX18.isZero() && realizedDebtChangeUsdX18.isZero()
                    && wethRewardChangeX18.isZero()
            ) {
                continue;
            }

            // add the vault's share of the market's unrealized and realized debt and weth reward to the cached values
            // which will update the vault's stored values at the parent context
            vaultTotalWethRewardChangeX18 = vaultTotalWethRewardChangeX18.add(wethRewardChangeX18);
            vaultTotalUnrealizedDebtChangeUsdX18 =
                vaultTotalUnrealizedDebtChangeUsdX18.add(unrealizedDebtChangeUsdX18);
            vaultTotalRealizedDebtChangeUsdX18 = vaultTotalRealizedDebtChangeUsdX18.add(realizedDebtChangeUsdX18);

            // update the last distributed debt and reward values to the vault's credit delegation to the given market
            // id, in order to keep next calculations consistent
            creditDelegation.updateVaultLastDistributedDebtAndReward(
                ud60x18(market.wethRewardPerVaultShare), marketUnrealizedDebtUsdX18, marketRealizedDebtUsdX18
            );
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

            // make sure there are markets connected to the vault
            if (self.connectedMarkets.length == 0) revert Errors.NoMarketsConnectedToVault(vaultId);

            // loads the connected markets storage pointer by taking the last configured market ids uint set
            EnumerableSet.UintSet storage connectedMarkets = self.connectedMarkets[self.connectedMarkets.length - 1];

            // cache the connected markets ids to avoid multiple storage reads, as we're going to loop over them twice
            // at `recalculateConnectedMarketsDebt` and `updateCreditDelegations`
            uint128[] memory connectedMarketsIdsCache = new uint128[](connectedMarkets.length());

            // iterate over each connected market id and distribute its debt so we can have the latest credit
            // delegation of the vault id being iterated to the provided `marketId`
            (
                uint128[] memory updatedConnectedMarketsIdsCache,
                UD60x18 vaultTotalWethRewardChangeX18,
                SD59x18 vaultTotalUnrealizedDebtChangeUsdX18,
                SD59x18 vaultTotalRealizedDebtChangeUsdX18
            ) = recalculateConnectedMarketsDebtAndReward(self, connectedMarketsIdsCache, true);

            // distributes the vault's total WETH reward change, earned from its connected markets

            SD59x18 vaultTotalWethRewardChangeSD59X18 = sd59x18(int256(vaultTotalWethRewardChangeX18.intoUint256()));
            self.wethRewardDistribution.distributeValue(vaultTotalWethRewardChangeSD59X18);

            // updates the vault's stored unrealized debt distributed from markets
            self.marketsUnrealizedDebtUsd = sd59x18(self.marketsUnrealizedDebtUsd).add(
                vaultTotalUnrealizedDebtChangeUsdX18
            ).intoInt256().toInt128();

            // updates the vault's stored unsettled realized debt distributed from markets
            self.unsettledRealizedDebtUsd =
                sd59x18(self.unsettledRealizedDebtUsd).add(vaultTotalRealizedDebtChangeUsdX18).intoInt256().toInt128();

            // update the vault's credit delegations
            (, SD59x18 vaultNewCreditCapacityUsdX18) =
                updateCreditDelegations(self, updatedConnectedMarketsIdsCache, false);

            emit LogUpdateVaultCreditCapacity(
                vaultId,
                vaultTotalUnrealizedDebtChangeUsdX18.intoInt256(),
                vaultTotalRealizedDebtChangeUsdX18.intoInt256(),
                vaultNewCreditCapacityUsdX18.intoInt256()
            );
        }
    }

    /// @notice Updates an existing vault with the specified parameters.
    /// @dev Modifies the vault's settings. Reverts if the vault does not exist.
    /// @param params The struct containing the parameters required to update the vault.
    function update(UpdateParams memory params) internal {
        Data storage self = load(params.vaultId);

        if (self.id == 0) {
            revert Errors.ZeroInput("vaultId");
        }

        self.depositCap = params.depositCap;
        self.withdrawalDelay = params.withdrawalDelay;
        self.isLive = params.isLive;
    }

    /// @notice Creates a new vault with the specified parameters.
    /// @dev Initializes the vault with the provided parameters. Reverts if the vault already exists.
    /// @param params The struct containing the parameters required to create the vault.
    function create(CreateParams memory params) internal {
        Data storage self = load(params.vaultId);

        if (self.id != 0) {
            revert Errors.VaultAlreadyExists(params.vaultId);
        }

        self.id = params.vaultId;
        self.depositCap = params.depositCap;
        self.withdrawalDelay = params.withdrawalDelay;
        self.indexToken = params.indexToken;
        self.collateral = params.collateral;
        self.isLive = true;
    }

    // todo: see if the `shouldRehydrateCache` parameter will be needed or not
    // todo: see if this function will be used elsewhere or if we can turn it into a private function for better
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
        returns (uint128[] memory rehydratedConnectedMarketsIdsCache, SD59x18 vaultCreditCapacityUsdX18)
    {
        rehydratedConnectedMarketsIdsCache = new uint128[](connectedMarketsIdsCache.length);
        // cache the vault id
        uint128 vaultId = self.id;

        // make sure there are markets connected to the vault
        if (self.connectedMarkets.length == 0) revert Errors.NoMarketsConnectedToVault(vaultId);

        // loads the connected markets storage pointer by taking the last configured market ids uint set
        EnumerableSet.UintSet storage connectedMarkets = self.connectedMarkets[self.connectedMarkets.length - 1];

        // loop over each connected market id that has been cached once again in order to update this vault's
        // credit delegations
        // TODO: update j to i
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

            if (self.totalCreditDelegationWeight == 0) {
                continue;
            }

            // // get the latest credit delegation share of the vault's credit capacity
            UD60x18 creditDelegationShareX18 =
                ud60x18(creditDelegation.weight).div(ud60x18(self.totalCreditDelegationWeight));

            // stores the vault's total credit capacity to be returned
            vaultCreditCapacityUsdX18 = getTotalCreditCapacityUsd(self);

            // if the vault's credit capacity went to zero or below, we set its credit delegation to that market
            // to zero
            // TODO: think about the implications of this, as it might lead to markets going insolvent due and bad
            // debt generation as the vault's collateral value unexpectedly tanks and / or its total debt
            // increases.
            UD60x18 newCreditDelegationUsdX18 = vaultCreditCapacityUsdX18.gt(SD59x18_ZERO)
                ? vaultCreditCapacityUsdX18.intoUD60x18().mul(creditDelegationShareX18)
                : UD60x18_ZERO;

            // loads the market's storage pointer
            Market.Data storage market = Market.load(connectedMarketId);
            // updates the market's vaults debt distributions with this vault's new credit delegation, i.e updates
            // its shares of the market's vaults debt distributions
            market.updateVaultCreditDelegation(vaultId, newCreditDelegationUsdX18);
        }
    }

    /// @notice Updates the vault shares of the connected markets
    /// @param self The vault storage pointer.
    /// @param actorId The actor id (vault id) to update the shares.
    /// @param updatedActorShares The updated actor shares.
    /// @param shouldIncrement Whether the shares should be incremented or decremented.
    function updateSharesOfConnectedMarkets(
        Data storage self,
        bytes32 actorId,
        UD60x18 updatedActorShares,
        bool shouldIncrement
    )
        internal
    {
        // loads the connected markets storage pointer by taking the last configured market ids uint set
        EnumerableSet.UintSet storage connectedMarkets = self.connectedMarkets[self.connectedMarkets.length - 1];

        // cache the connected markets ids
        uint128[] memory connectedMarketsIdsCache = new uint128[](connectedMarkets.length());

        // iterate over each connected market id
        for (uint256 i; i < connectedMarketsIdsCache.length; i++) {
            // loads the memory cached market id
            uint128 connectedMarketId = connectedMarkets.at(i).toUint128();

            // loads the market storage pointer
            Market.Data storage market = Market.load(connectedMarketId);

            // update the market's shares of the actor
            UD60x18 totalSharesX18 = ud60x18(market.vaultsDebtDistribution.totalShares);
            UD60x18 updatedSharesX18;

            if (shouldIncrement) {
                updatedSharesX18 = totalSharesX18.add(updatedActorShares);
            } else {
                updatedSharesX18 = totalSharesX18.sub(updatedActorShares);
            }

            market.vaultsDebtDistribution.setActorShares(actorId, updatedSharesX18);
        }
    }
}
