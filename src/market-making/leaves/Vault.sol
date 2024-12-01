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

/// @dev NOTE: each market's realized debt must always be distributed as unsettledRealizedDebt to vaults following the
/// Debt Distribution System.
/// @dev Vault's debt for asset settlement purposes = unsettledRealizedDebtUsd
/// @dev Vault's debt for credit delegation and ADL purposes = marketsUnrealizedDebtUsd + unsettledRealizedDebtUsd
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
        int256 vaultRealizedDebtChangeUsd,
        int256 vaultUnrealizedDebtChangeUsd,
        uint256 vaultUsdcCreditChange,
        uint256 vaultWethRewardChange,
        int256 vaultNewCreditCapacityUsd
    );

    /// @param id The vault identifier.
    // todo: define final credit delegation weight system
    /// @param totalCreditDelegationWeight The total amount of credit delegation weight in the vault.
    /// @param depositCap The maximum amount of collateral assets that can be deposited in the vault.
    /// @param withdrawalDelay The delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @param lockedCreditRatio The configured ratio that determines how much of the vault's total assets can't be
    /// withdrawn according to the Vault's total debt, in order to secure the credit delegation system.
    /// @param marketsUnrealizedDebtUsd The total amount of unrealized debt coming from markets in USD.
    /// @param unsettledRealizedDebtUsd The total amount of unsettled debt in USD.
    /// @param marketsDepositedUsdc The total amount of credit deposits from markets that have been converted and
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
        uint128 marketsDepositedUsdc;
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
    /// @return creditCapacityUsdX18 The vault's total credit capacity in USD.
    function getTotalCreditCapacityUsd(Data storage self) internal view returns (SD59x18 creditCapacityUsdX18) {
        // load the collateral configuration storage pointer
        Collateral.Data storage collateral = self.collateral;

        // fetch the zlp vault's total assets amount
        UD60x18 totalAssetsX18 = ud60x18(IERC4626(collateral.asset).totalAssets());
        // calculate the total assets value in usd terms
        UD60x18 totalAssetsUsdX18 = collateral.getAdjustedPrice().mul(totalAssetsX18);

        // calculate the vault's credit capacity in usd terms
        creditCapacityUsdX18 = totalAssetsUsdX18.intoSD59x18().sub(getTotalDebt(self));
    }

    /// @notice Returns the vault's total debt distributed from conneted markets.
    /// @dev Takes into account the unrealized debt, the unsettled (yet to be settled) realized debt and the usdc
    /// credit deposited by markets.
    /// @param self The vault storage pointer.
    function getTotalDebt(Data storage self) internal view returns (SD59x18 totalDebtUsdX18) {
        totalDebtUsdX18 = sd59x18(self.marketsUnrealizedDebtUsd).add(sd59x18(self.unsettledRealizedDebtUsd)).add(
            ud60x18(self.marketsDepositedUsdc).intoSD59x18()
        );
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

    struct RecalculateConnectedMarketsState_Context {
        uint128 vaultId;
        uint128 connectedMarketId;
        SD59x18 marketUnrealizedDebtUsdX18;
        SD59x18 marketRealizedDebtUsdX18;
        SD59x18 realizedDebtChangeUsdX18;
        SD59x18 unrealizedDebtChangeUsdX18;
        UD60x18 usdcCreditChangeX18;
        UD60x18 wethRewardChangeX18;
    }

    // TODO: see if this function will be used elsewhere or if we can turn it into a private function for better
    // testability / visibility
    /// @notice Recalculates the latest debt of each market connected to a vault, distributing its total debt to it.
    /// @param self The vault storage pointer.
    /// @param connectedMarketsIdsCache The cached connected markets ids.
    /// @param shouldRehydrateCache Whether the connected markets ids cache should be rehydrated or not.
    /// @return rehydratedConnectedMarketsIdsCache The potentially rehydrated connected markets ids cache.
    /// @return vaultTotalRealizedDebtChangeUsdX18 The vault's total realized debt change in USD.
    /// @return vaultTotalUnrealizedDebtChangeUsdX18 The vault's total unrealized debt change in USD.
    /// @return vaultTotalUsdcCreditChangeX18 The vault's total USDC credit change.
    /// @return vaultTotalWethRewardChangeX18 The vault's total WETH reward change.
    function recalculateConnectedMarketsState(
        Data storage self,
        uint128[] memory connectedMarketsIdsCache,
        bool shouldRehydrateCache
    )
        internal
        returns (
            uint128[] memory rehydratedConnectedMarketsIdsCache,
            SD59x18 vaultTotalRealizedDebtChangeUsdX18,
            SD59x18 vaultTotalUnrealizedDebtChangeUsdX18,
            UD60x18 vaultTotalUsdcCreditChangeX18,
            UD60x18 vaultTotalWethRewardChangeX18
        )
    {
        RecalculateConnectedMarketsState_Context memory ctx;
        rehydratedConnectedMarketsIdsCache = new uint128[](connectedMarketsIdsCache.length);

        // cache the vault id
        ctx.vaultId = self.id;

        // make sure there are markets connected to the vault
        if (self.connectedMarkets.length == 0) revert Errors.NoMarketsConnectedToVault(ctx.vaultId);

        // loads the connected markets storage pointer by taking the last configured market ids uint set
        EnumerableSet.UintSet storage connectedMarkets = self.connectedMarkets[self.connectedMarkets.length - 1];

        for (uint256 i; i < connectedMarketsIdsCache.length; i++) {
            if (shouldRehydrateCache) {
                rehydratedConnectedMarketsIdsCache[i] = connectedMarkets.at(i).toUint128();
            } else {
                rehydratedConnectedMarketsIdsCache[i] = connectedMarketsIdsCache[i];
            }

            // loads the memory cached market id
            ctx.connectedMarketId = rehydratedConnectedMarketsIdsCache[i];
            // loads the market storage pointer
            Market.Data storage market = Market.load(ctx.connectedMarketId);

            // first we cache the market's unrealized and realized debt
            ctx.marketUnrealizedDebtUsdX18 = market.getUnrealizedDebtUsd();

            // get the latest realized debt of the market
            ctx.marketRealizedDebtUsdX18 = market.getRealizedDebtUsd();
            // distribute the market's debt to its connected vaults
            market.distributeDebtToVaults(ctx.marketUnrealizedDebtUsdX18, ctx.marketRealizedDebtUsdX18);

            // load the credit delegation to the given market id
            CreditDelegation.Data storage creditDelegation = CreditDelegation.load(ctx.vaultId, ctx.connectedMarketId);

            // get the vault's accumulated debt, credit and reward changes from the market to update its stored values
            (
                ctx.realizedDebtChangeUsdX18,
                ctx.unrealizedDebtChangeUsdX18,
                ctx.usdcCreditChangeX18,
                ctx.wethRewardChangeX18
            ) = market.getVaultAccumulatedValues(
                ud60x18(creditDelegation.valueUsd),
                sd59x18(creditDelegation.lastVaultDistributedRealizedDebtUsdPerShare),
                sd59x18(creditDelegation.lastVaultDistributedUnrealizedDebtUsdPerShare),
                ud60x18(creditDelegation.lastVaultDistributedUsdcCreditPerShare),
                ud60x18(creditDelegation.lastVaultDistributedWethRewardPerShare)
            );

            // if there's been no change in any of the returned values, we can iterate to the next
            // market id
            if (
                ctx.realizedDebtChangeUsdX18.isZero() && ctx.unrealizedDebtChangeUsdX18.isZero()
                    && ctx.usdcCreditChangeX18.isZero() && ctx.wethRewardChangeX18.isZero()
            ) {
                continue;
            }

            // update the vault's state by adding its share of the market's latest state variables
            vaultTotalRealizedDebtChangeUsdX18 = vaultTotalRealizedDebtChangeUsdX18.add(ctx.realizedDebtChangeUsdX18);
            vaultTotalUnrealizedDebtChangeUsdX18 =
                vaultTotalUnrealizedDebtChangeUsdX18.add(ctx.unrealizedDebtChangeUsdX18);
            vaultTotalUsdcCreditChangeX18 = vaultTotalUsdcCreditChangeX18.add(ctx.usdcCreditChangeX18);
            vaultTotalWethRewardChangeX18 = vaultTotalWethRewardChangeX18.add(ctx.wethRewardChangeX18);

            // update the last distributed debt, credit and reward values to the vault's credit delegation to the
            // given market id, in order to keep next calculations consistent
            creditDelegation.updateVaultLastDistributedValues(
                sd59x18(market.realizedDebtUsdPerVaultShare),
                sd59x18(market.unrealizedDebtUsdPerVaultShare),
                ud60x18(market.usdcCreditPerVaultShare),
                ud60x18(market.wethRewardPerVaultShare)
            );
        }
    }

    /// @notice Recalculates the latest credit capacity of the provided vaults ids taking into account their latest
    /// assets and debt usd denonimated values.
    /// @dev We use a `uint256` array because a market's connected vaults ids are stored at a `EnumerableSet.UintSet`.
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
                SD59x18 vaultTotalRealizedDebtChangeUsdX18,
                SD59x18 vaultTotalUnrealizedDebtChangeUsdX18,
                UD60x18 vaultTotalUsdcCreditChangeX18,
                UD60x18 vaultTotalWethRewardChangeX18
            ) = recalculateConnectedMarketsState(self, connectedMarketsIdsCache, true);

            // updates the vault's stored unsettled realized debt distributed from markets
            self.unsettledRealizedDebtUsd =
                sd59x18(self.unsettledRealizedDebtUsd).add(vaultTotalRealizedDebtChangeUsdX18).intoInt256().toInt128();

            // updates the vault's stored unrealized debt distributed from markets
            self.marketsUnrealizedDebtUsd = sd59x18(self.marketsUnrealizedDebtUsd).add(
                vaultTotalUnrealizedDebtChangeUsdX18
            ).intoInt256().toInt128();

            // adds the vault's total USDC credit change, earned from its connected markets, to the
            // `marketsDepositedUsdc` variable
            self.marketsDepositedUsdc =
                ud60x18(self.marketsDepositedUsdc).add(vaultTotalUsdcCreditChangeX18).intoUint128();

            // distributes the vault's total WETH reward change, earned from its connected markets
            SD59x18 vaultTotalWethRewardChangeSD59X18 = sd59x18(int256(vaultTotalWethRewardChangeX18.intoUint256()));
            self.wethRewardDistribution.distributeValue(vaultTotalWethRewardChangeSD59X18);

            // update the vault's credit delegations
            (, SD59x18 vaultNewCreditCapacityUsdX18) =
                updateCreditDelegations(self, updatedConnectedMarketsIdsCache, false);

            emit LogUpdateVaultCreditCapacity(
                vaultId,
                vaultTotalRealizedDebtChangeUsdX18.intoInt256(),
                vaultTotalUnrealizedDebtChangeUsdX18.intoInt256(),
                vaultTotalUsdcCreditChangeX18.intoUint256(),
                vaultTotalWethRewardChangeX18.intoUint256(),
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

    // todo: we may need to remove the return value to save gas / remove if not needed
    /// @notice Updates the vault's credit delegations to its connected markets, using the provided cache of connected
    /// markets ids.
    /// @dev This function assumes that the connected markets ids cache is up to date with the stored markets ids. If
    /// this invariant resolves to false, the function will not work as expected.
    /// @dev We assume self.totalCreditDelegationWeight is always greater than zero, as it's verified during
    /// configuration.
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
        for (uint256 i; i < connectedMarketsIdsCache.length; i++) {
            // rehydrate the markets ids cache if needed
            if (shouldRehydrateCache) {
                rehydratedConnectedMarketsIdsCache[i] = connectedMarkets.at(i).toUint128();
            } else {
                rehydratedConnectedMarketsIdsCache[i] = connectedMarketsIdsCache[i];
            }

            // loads the memory cached market id
            uint128 connectedMarketId = rehydratedConnectedMarketsIdsCache[i];

            // load the credit delegation to the given market id
            CreditDelegation.Data storage creditDelegation = CreditDelegation.load(vaultId, connectedMarketId);

            // cache the previous credit delegation value
            UD60x18 previousCreditDelegationUsdX18 = ud60x18(creditDelegation.valueUsd);

            // // get the latest credit delegation share of the vault's credit capacity
            UD60x18 creditDelegationShareX18 =
                ud60x18(creditDelegation.weight).div(ud60x18(self.totalCreditDelegationWeight));

            // stores the vault's total credit capacity to be returned
            vaultCreditCapacityUsdX18 = getTotalCreditCapacityUsd(self);

            // if the vault's credit capacity went to zero or below, we set its credit delegation to that market
            // to zero
            UD60x18 newCreditDelegationUsdX18 = vaultCreditCapacityUsdX18.gt(SD59x18_ZERO)
                ? vaultCreditCapacityUsdX18.intoUD60x18().mul(creditDelegationShareX18)
                : UD60x18_ZERO;

            // calculate the delta applied to the market's total delegated credit
            UD60x18 creditDeltaUsdX18 = newCreditDelegationUsdX18.sub(previousCreditDelegationUsdX18);

            // loads the market's storage pointer
            Market.Data storage market = Market.load(connectedMarketId);

            // performs state update
            market.updateTotalDelegatedCredit(creditDeltaUsdX18);

            // if new credit delegation is zero, we clear the credit delegation storage
            if (newCreditDelegationUsdX18.isZero()) {
                creditDelegation.clear();
            } else {
                // update the credit delegation stored usd value
                creditDelegation.valueUsd = newCreditDelegationUsdX18.intoUint128();
            }
        }
    }

    // todo: rework this on a separate PR
    // /// @notice Updates the vault shares of the connected markets
    // /// @param self The vault storage pointer.
    // /// @param actorId The actor id (vault id) to update the shares.
    // /// @param updatedActorShares The updated actor shares.
    // /// @param shouldIncrement Whether the shares should be incremented or decremented.
    // function updateSharesOfConnectedMarkets(
    //     Data storage self,
    //     bytes32 actorId,
    //     UD60x18 updatedActorShares,
    //     bool shouldIncrement
    // )
    //     internal
    // {
    //     // loads the connected markets storage pointer by taking the last configured market ids uint set
    //     EnumerableSet.UintSet storage connectedMarkets = self.connectedMarkets[self.connectedMarkets.length - 1];

    //     // cache the connected markets ids
    //     uint128[] memory connectedMarketsIdsCache = new uint128[](connectedMarkets.length());

    //     // iterate over each connected market id
    //     for (uint256 i; i < connectedMarketsIdsCache.length; i++) {
    //         // loads the memory cached market id
    //         uint128 connectedMarketId = connectedMarkets.at(i).toUint128();

    //         // loads the market storage pointer
    //         Market.Data storage market = Market.load(connectedMarketId);

    //         // update the market's shares of the actor
    //         UD60x18 totalSharesX18 = ud60x18(market.vaultsDebtDistribution.totalShares);
    //         UD60x18 updatedSharesX18;

    //         if (shouldIncrement) {
    //             updatedSharesX18 = totalSharesX18.add(updatedActorShares);
    //         } else {
    //             updatedSharesX18 = totalSharesX18.sub(updatedActorShares);
    //         }

    //         market.vaultsDebtDistribution.setActorShares(actorId, updatedSharesX18);
    //     }
    // }
}
