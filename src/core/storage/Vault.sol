//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Zaros dependencies
import { Distribution } from "./Distribution.sol";
import { RewardDistribution } from "./RewardDistribution.sol";
import { ScalableMapping } from "./ScalableMapping.sol";
import { VaultEpoch } from "./VaultEpoch.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

/**
 * @title Tracks collateral and debt distributions in a pool, for a specific collateral type.
 *
 * I.e. if a pool supports bb-a-USD and wstETH collaterals, it will have a bb-a-USD  Vault, and a wstETH Vault.
 *
 * The Vault data structure is itself split into VaultEpoch sub-structures. This facilitates liquidations,
 * so that whenever one occurs, a clean state of all data is achieved by simply incrementing the epoch index.
 *
 * It is recommended to understand VaultEpoch before understanding this object.
 */
library Vault {
    using Distribution for Distribution.Data;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using RewardDistribution for RewardDistribution.Data;
    using SafeCast for uint256;
    using ScalableMapping for ScalableMapping.Data;
    using VaultEpoch for VaultEpoch.Data;

    /// @dev Constant base domain used to access a given vault's storage slot
    string internal constant VAULT_DOMAIN = "fi.zaros.core.Vault";

    /**
     * @dev Thrown when a non-existent reward distributor is referenced
     */
    error Zaros_Vault_RewardDistributorNotFound();

    struct Data {
        address collateralType;
        /**
         * @dev The vault's current epoch number.
         *
         * Vault data is divided into epochs. An epoch changes when an entire vault is liquidated.
         */
        uint256 epoch;
        /**
         * @dev Unused property, maintained for backwards compatibility in storage layout.
         */
        // solhint-disable-next-line private-vars-leading-underscore
        bytes32 __slotAvailableForFutureUse;
        /**
         * @dev The previous debt of the vault, when `updateCreditCapacity` was last called by the Pool.
         */
        int128 prevTotalDebt;
        /**
         * @dev Vault data for all the liquidation cycles divided into epochs.
         */
        mapping(uint256 => VaultEpoch.Data) epochData;
        /**
         * @dev Tracks available rewards, per user, for this vault.
         */
        mapping(bytes32 => RewardDistribution.Data) rewards;
        /**
         * @dev Tracks reward ids, for this vault.
         */
        SetUtil.Bytes32Set rewardIds;
    }

    function load(address collateralType) internal view returns (Data storage vault) {
        bytes32 s = keccak256(VAULT_DOMAIN, collateralType);
        assembly {
            vault.slot := s
        }
    }

    /**
     * @dev Return's the VaultEpoch data for the current epoch.
     */
    function currentEpoch(Data storage self) internal view returns (VaultEpoch.Data storage epoch) {
        return self.epochData[self.epoch];
    }

    /**
     * @dev Updates the vault's credit capacity as the value of its collateral minus its debt.
     *
     * Called as a ticker when users interact with pools, allowing pools to set
     * vaults' credit capacity shares within them.
     *
     * Returns the amount of collateral that this vault is providing in net USD terms.
     */
    function updateCreditCapacity(
        Data storage self,
        UD60x18 collateralPrice
    )
        internal
        returns (UD60x18 usdWeight, SD59x18 totalDebt, SD59x18 deltaDebt)
    {
        VaultEpoch.Data storage epochData = currentEpoch(self);

        usdWeight = (epochData.collateralAmounts.totalAmount()).mul(collateralPrice);

        totalDebt = epochData.totalDebt();

        deltaDebt = totalDebt.sub(self.prevTotalDebt);

        self.prevTotalDebt = totalDebt.safeCastTo128();
    }

    /**
     * @dev Updated the value per share of the current epoch's incoming debt distribution.
     */
    function distributeDebtToAccounts(Data storage self, SD59x18 debtChange) internal {
        currentEpoch(self).distributeDebtToAccounts(debtChange);
    }

    /**
     * @dev Consolidates an accounts debt.
     */
    function consolidateAccountDebt(Data storage self, uint128 accountId) internal returns (SD59x18) {
        return currentEpoch(self).consolidateAccountDebt(accountId);
    }

    /**
     * @dev Traverses available rewards for this vault, and updates an accounts
     * claim on them according to the amount of debt shares they have.
     */
    function updateRewards(
        Data storage self,
        uint128 accountId,
        uint128 poolId,
        address collateralType
    )
        internal
        returns (uint256[] memory rewards, address[] memory distributors)
    {
        rewards = new uint256[](self.rewardIds.length());
        distributors = new address[](self.rewardIds.length());

        uint256 numRewards = self.rewardIds.length();
        for (uint256 i = 0; i < numRewards; i++) {
            RewardDistribution.Data storage dist = self.rewards[self.rewardIds.valueAt(i + 1)];

            if (address(dist.distributor) == address(0)) {
                continue;
            }

            distributors[i] = address(dist.distributor);
            rewards[i] = updateReward(self, accountId, poolId, collateralType, self.rewardIds.valueAt(i + 1));
        }
    }

    /**
     * @dev Traverses available rewards for this vault and the reward id, and updates an accounts
     * claim on them according to the amount of debt shares they have.
     */
    function updateReward(
        Data storage self,
        uint128 accountId,
        uint128 poolId,
        address collateralType,
        bytes32 rewardId
    )
        internal
        returns (uint256)
    {
        UD60x18 totalShares = ud60x18(currentEpoch(self).accountsDebtDistribution.totalShares);
        UD60x18 actorShares = currentEpoch(self).accountsDebtDistribution.getActorShares(accountId.toBytes32());

        RewardDistribution.Data storage dist = self.rewards[rewardId];

        if (address(dist.distributor) == address(0)) {
            revert Zaros_Vault_RewardDistributorNotFound();
        }

        dist.distributor.onStakerChanged(accountId, poolId, collateralType, actorShares);

        dist.rewardPerShare += dist.updateEntry(totalShares).intoUint128();

        dist.claimStatus[accountId].pendingSend +=
            actorShares.mul(dist.rewardPerShare - dist.claimStatus[accountId].lastRewardPerShare).intoUint128();

        dist.claimStatus[accountId].lastRewardPerShare = dist.rewardPerShare;

        return dist.claimStatus[accountId].pendingSend;
    }

    /**
     * @dev Increments the current epoch index, effectively producing a
     * completely blank new VaultEpoch data structure in the vault.
     */
    function reset(Data storage self) internal {
        self.epoch++;
    }

    /**
     * @dev Returns the vault's combined debt (consolidated and unconsolidated),
     * for the current epoch.
     */
    function currentDebt(Data storage self) internal view returns (SD59x18) {
        return currentEpoch(self).totalDebt();
    }

    /**
     * @dev Returns the total value in the Vault's collateral distribution, for the current epoch.
     */
    function currentCollateral(Data storage self) internal view returns (UD60x18) {
        return currentEpoch(self).collateralAmounts.totalAmount();
    }

    /**
     * @dev Returns an account's collateral value in this vault's current epoch.
     */
    function currentAccountCollateral(Data storage self, uint128 accountId) internal view returns (UD60x18) {
        return currentEpoch(self).getAccountCollateral(accountId);
    }
}
