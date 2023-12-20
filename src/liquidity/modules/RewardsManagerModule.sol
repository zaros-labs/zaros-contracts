// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IRewardDistributor } from "@zaros/reward-distributor/interfaces/IRewardDistributor.sol";
import { IRewardsManagerModule } from "../interfaces/IRewardsManagerModule.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { FeatureFlag } from "@zaros/utils/storage/FeatureFlag.sol";
import { Account } from "../storage/Account.sol";
import { Distribution } from "../storage/Distribution.sol";
import { MarketManager } from "../storage/MarketManager.sol";
import { RewardDistribution } from "../storage/RewardDistribution.sol";
import { Vault } from "../storage/Vault.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

/**
 * @title Module for connecting rewards distributors to vaults.
 * @dev See IRewardsManagerModule.
 */
abstract contract RewardsManagerModule is IRewardsManagerModule, Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using SafeCast for uint256;
    using Vault for Vault.Data;
    using Distribution for Distribution.Data;
    using RewardDistribution for RewardDistribution.Data;

    uint256 private constant _MAX_REWARD_DISTRIBUTIONS = 10;

    function getRewardRate(address collateralType, address distributor) external view override returns (uint256) {
        return _getRewardRate(collateralType, distributor).intoUint256();
    }

    function registerRewardDistributor(address collateralType, address distributor) external override onlyOwner {
        Vault.Data storage vault = MarketManager.load().vaults[collateralType];
        EnumerableSet.Bytes32Set storage rewardIds = vault.rewardIds;

        if (rewardIds.length() > _MAX_REWARD_DISTRIBUTIONS) {
            revert Errors.InvalidParameter("index", "too large");
        }

        bytes32 rewardId = _getRewardId(collateralType, distributor);
        if (rewardIds.contains(rewardId)) {
            revert Errors.InvalidParameter("distributor", "is already registered");
        }
        if (address(vault.rewards[rewardId].distributor) != address(0)) {
            revert Errors.InvalidParameter("distributor", "cant be re-registered");
        }

        rewardIds.add(rewardId);
        if (distributor == address(0)) {
            revert Errors.InvalidParameter("distributor", "must be non-zero");
        }
        vault.rewards[rewardId].distributor = IRewardDistributor(distributor);

        emit LogRegisterRewardsDistributor(collateralType, distributor);
    }

    function distributeRewards(
        address collateralType,
        uint256 amount,
        uint64 start,
        uint32 duration
    )
        external
        override
    {
        Vault.Data storage vault = MarketManager.load().vaults[collateralType];
        EnumerableSet.Bytes32Set storage rewardIds = vault.rewardIds;

        bytes32 rewardId = _getRewardId(collateralType, msg.sender);
        if (!rewardIds.contains(rewardId)) {
            revert Errors.InvalidParameter("collateralType-distributor", "reward is not registered");
        }

        RewardDistribution.Data storage reward = vault.rewards[rewardId];

        reward.rewardPerShare = ud60x18(reward.rewardPerShare).add(
            reward.distribute(
                vault.currentEpoch().accountsDebtDistribution, ud60x18(amount).intoSD59x18(), start, duration
            ).intoUD60x18()
        ).intoUint256().toUint128();

        emit LogDistributeRewards(collateralType, msg.sender, amount, start, duration);
    }

    function updateRewards(
        address collateralType,
        uint128 accountId
    )
        external
        override
        returns (UD60x18[] memory, address[] memory)
    {
        Account.exists(accountId);
        Vault.Data storage vault = MarketManager.load().vaults[collateralType];
        return vault.updateRewards(accountId);
    }

    function claimRewards(
        uint128 accountId,
        address collateralType,
        address distributor
    )
        external
        override
        returns (uint256)
    {
        FeatureFlag.ensureAccessToFeature(Constants.CLAIM_FEATURE_FLAG);
        Account.loadExistingAccountAndVerifySender(accountId);

        Vault.Data storage vault = MarketManager.load().vaults[collateralType];
        bytes32 rewardId = keccak256(abi.encode(collateralType, distributor));

        if (address(vault.rewards[rewardId].distributor) != distributor) {
            revert Errors.InvalidParameter("invalid-params", "reward is not found");
        }

        uint256 rewardAmount = vault.updateReward(accountId, rewardId).intoUint256();

        RewardDistribution.Data storage reward = vault.rewards[rewardId];
        reward.claimStatus[accountId].pendingSend = 0;
        bool success =
            vault.rewards[rewardId].distributor.payout(accountId, collateralType, msg.sender, rewardAmount);

        if (!success) {
            revert Zaros_RewardsManagerModule_RewardUnavailable(distributor);
        }

        emit LogClaimRewards(accountId, collateralType, address(vault.rewards[rewardId].distributor), rewardAmount);

        return rewardAmount;
    }

    function _getRewardRate(address collateralType, address distributor) internal view returns (UD60x18) {
        Vault.Data storage vault = MarketManager.load().vaults[collateralType];
        UD60x18 totalShares = ud60x18(vault.currentEpoch().accountsDebtDistribution.totalShares);
        bytes32 rewardId = _getRewardId(collateralType, distributor);

        uint256 currentTime = block.timestamp;

        // No rewards are currently being distributed if the distributor doesn't exist, they are scheduled to be
        // distributed in the future, or the distribution as already completed
        if (
            address(vault.rewards[rewardId].distributor) == address(0)
                || vault.rewards[rewardId].start > currentTime
                || vault.rewards[rewardId].start + vault.rewards[rewardId].duration <= currentTime
        ) {
            return UD_ZERO;
        }

        return sd59x18(vault.rewards[rewardId].scheduledValue).intoUD60x18().div(
            ud60x18(vault.rewards[rewardId].duration).div(totalShares)
        );
    }

    function _getRewardId(address collateralType, address distributor) internal pure returns (bytes32) {
        return keccak256(abi.encode(collateralType, distributor));
    }

    function removeRewardsDistributor(address collateralType, address distributor) external override onlyOwner {
        Vault.Data storage vault = MarketManager.load().vaults[collateralType];
        EnumerableSet.Bytes32Set storage rewardIds = vault.rewardIds;

        bytes32 rewardId = _getRewardId(collateralType, distributor);

        if (!rewardIds.contains(rewardId)) {
            revert Errors.InvalidParameter("distributor", "is not registered");
        }

        rewardIds.remove(rewardId);

        if (distributor == address(0)) {
            revert Errors.InvalidParameter("distributor", "must be non-zero");
        }

        RewardDistribution.Data storage reward = vault.rewards[rewardId];

        // ensure rewards emission is stopped (users can still come in to claim rewards after the fact)
        reward.rewardPerShare = ud60x18(reward.rewardPerShare).add(
            reward.distribute(vault.currentEpoch().accountsDebtDistribution, SD_ZERO, 0, 0).intoUD60x18()
        ).intoUint256().toUint128();

        emit LogRemoveRewardsDistributor(collateralType, distributor);
    }
}
