// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IRewardsManagerModule } from "../interfaces/IRewardsManagerModule.sol";
import {  FeatureFlag } from "@zaros/utils/storage/FeatureFlag.sol";
import { Account } from "../storage/Account.sol";
import { AccountRBAC } from "../storage/AccountRBAC.sol";
import { MarketManager } from "../storage/MarketManager.sol";
import { Vault } from "../storage/Vault.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

/**
 * @title Module for connecting rewards distributors to vaults.
 * @dev See IRewardsManagerModule.
 */
contract RewardsManagerModule is IRewardsManagerModule {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using Vault for Vault.Data;
    using Distribution for Distribution.Data;
    using RewardDistribution for RewardDistribution.Data;

    uint256 private constant _MAX_REWARD_DISTRIBUTIONS = 10;

    bytes32 private constant _CLAIM_FEATURE_FLAG = "claimRewards";

    /**
     * @inheritdoc IRewardsManagerModule
     */
    function registerRewardsDistributor(
        address collateralType,
        address distributor
    ) external override {
        Vault.Data storage vault = Vault.load(collateralType);
        EnumerableSet.Bytes32Set storage rewardIds = pool.vaults[collateralType].rewardIds;

        if (pool.owner != msg.sender) {
            revert AccessError.Unauthorized(msg.sender);
        }

        // Limit the maximum amount of rewards distributors can be connected to each vault to prevent excessive gas usage on other calls
        if (rewardIds.length() > _MAX_REWARD_DISTRIBUTIONS) {
            revert ParameterError.InvalidParameter("index", "too large");
        }

        bytes32 rewardId = _getRewardId(collateralType, distributor);
        if (rewardIds.contains(rewardId)) {
            revert ParameterError.InvalidParameter("distributor", "is already registered");
        }
        if (address(vault.rewards[rewardId].distributor) != address(0)) {
            revert ParameterError.InvalidParameter("distributor", "cant be re-registered");
        }

        rewardIds.add(rewardId);
        if (distributor == address(0)) {
            revert ParameterError.InvalidParameter("distributor", "must be non-zero");
        }
        vault.rewards[rewardId].distributor = IRewardDistributor(distributor);

        emit LogRegisterRewardsDistributor( collateralType, distributor);
    }

    /**
     * @inheritdoc IRewardsManagerModule
     */
    function distributeRewards(
        address collateralType,
        uint256 amount,
        uint64 start,
        uint32 duration
    ) external override {
        Vault.Data storage vault = Vault.load(collateralType);
        EnumerableSet.Bytes32Set storage rewardIds = pool.vaults[collateralType].rewardIds;

        // Identify the reward id for the caller, and revert if it is not a registered reward distributor.
        bytes32 rewardId = _getRewardId(collateralType, msg.sender);
        if (!rewardIds.contains(rewardId)) {
            revert ParameterError.InvalidParameter(
                "collateralType-distributor",
                "reward is not registered"
            );
        }

        RewardDistribution.Data storage reward = vault.rewards[rewardId];

        reward.rewardPerShareD18 += reward
            .distribute(
                vault.currentEpoch().accountsDebtDistribution,
                amount.toInt(),
                start,
                duration
            )
            .toUint()
            .to128();

        emit LogDistributeRewards(collateralType, msg.sender, amount, start, duration);
    }

    /**
     * @inheritdoc IRewardsManagerModule
     */
    function updateRewards(
        address collateralType,
        uint128 accountId
    ) external override returns (uint256[] memory, address[] memory) {
        Account.exists(accountId);
        Vault.Data storage vault = Vault.load(collateralType);
        return vault.updateRewards(accountId, poolId, collateralType);
    }

    /**
     * @inheritdoc IRewardsManagerModule
     */
    function getRewardRate(
        uint128 poolId,
        address collateralType,
        address distributor
    ) external view override returns (uint256) {
        return _getRewardRate(poolId, collateralType, distributor);
    }

    /**
     * @inheritdoc IRewardsManagerModule
     */
    function claimRewards(
        uint128 accountId,
        uint128 poolId,
        address collateralType,
        address distributor
    ) external override returns (uint256) {
        FeatureFlag.ensureAccessToFeature(_CLAIM_FEATURE_FLAG);
        Account.loadAccountAndValidatePermission(accountId, AccountRBAC._REWARDS_PERMISSION);

        Vault.Data storage vault = Pool.load(poolId).vaults[collateralType];
        bytes32 rewardId = keccak256(abi.encode(poolId, collateralType, distributor));

        if (address(vault.rewards[rewardId].distributor) != distributor) {
            revert ParameterError.InvalidParameter("invalid-params", "reward is not found");
        }

        uint256 rewardAmount = vault.updateReward(accountId, poolId, collateralType, rewardId);

        RewardDistribution.Data storage reward = vault.rewards[rewardId];
        reward.claimStatus[accountId].pendingSendD18 = 0;
        bool success = vault.rewards[rewardId].distributor.payout(
            accountId,
            poolId,
            collateralType,
            msg.sender,
            rewardAmount
        );

        if (!success) {
            revert RewardUnavailable(distributor);
        }

        emit RewardsClaimed(
            accountId,
            poolId,
            collateralType,
            address(vault.rewards[rewardId].distributor),
            rewardAmount
        );

        return rewardAmount;
    }

    /**
     * @dev Return the amount of rewards being distributed to a vault per second
     */
    function _getRewardRate(
        uint128 poolId,
        address collateralType,
        address distributor
    ) internal view returns (uint256) {
        Vault.Data storage vault = Pool.load(poolId).vaults[collateralType];
        uint256 totalShares = vault.currentEpoch().accountsDebtDistribution.totalSharesD18;
        bytes32 rewardId = _getRewardId(poolId, collateralType, distributor);

        int256 curTime = block.timestamp.toInt();

        // No rewards are currently being distributed if the distributor doesn't exist, they are scheduled to be distributed in the future, or the distribution as already completed
        if (
            address(vault.rewards[rewardId].distributor) == address(0) ||
            vault.rewards[rewardId].start > curTime.toUint() ||
            vault.rewards[rewardId].start + vault.rewards[rewardId].duration <= curTime.toUint()
        ) {
            return 0;
        }

        return
            vault.rewards[rewardId].scheduledValueD18.to256().toUint().divDecimal(
                vault.rewards[rewardId].duration.to256().divDecimal(totalShares)
            );
    }

    /**
     * @dev Generate an ID for a rewards distributor connection by hashing its address with the vault's collateral type address and pool id
     */
    function _getRewardId(
        uint128 poolId,
        address collateralType,
        address distributor
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(poolId, collateralType, distributor));
    }

    /**
     * @inheritdoc IRewardsManagerModule
     */
    function removeRewardsDistributor(
        uint128 poolId,
        address collateralType,
        address distributor
    ) external override {
        Pool.Data storage pool = Pool.load(poolId);
        EnumerableSet.Bytes32Set storage rewardIds = pool.vaults[collateralType].rewardIds;

        if (pool.owner != msg.sender) {
            revert AccessError.Unauthorized(msg.sender);
        }

        bytes32 rewardId = _getRewardId(poolId, collateralType, distributor);

        if (!rewardIds.contains(rewardId)) {
            revert ParameterError.InvalidParameter("distributor", "is not registered");
        }

        rewardIds.remove(rewardId);

        if (distributor == address(0)) {
            revert ParameterError.InvalidParameter("distributor", "must be non-zero");
        }

        RewardDistribution.Data storage reward = pool.vaults[collateralType].rewards[rewardId];

        // ensure rewards emission is stopped (users can still come in to claim rewards after the fact)
        reward.rewardPerShareD18 += reward
            .distribute(
                pool.vaults[collateralType].currentEpoch().accountsDebtDistribution,
                0,
                0,
                0
            )
            .toUint()
            .to128();

        emit RewardsDistributorRemoved(poolId, collateralType, distributor);
    }
}
