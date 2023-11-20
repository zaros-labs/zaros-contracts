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
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

library Vault {
    using Distribution for Distribution.Data;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using RewardDistribution for RewardDistribution.Data;
    using SafeCast for int256;
    using SafeCast for uint256;
    using ScalableMapping for ScalableMapping.Data;
    using VaultEpoch for VaultEpoch.Data;

    error Zaros_Vault_RewardDistributorNotFound();

    struct Data {
        address collateralType;
        uint256 epoch;
        mapping(uint256 index => VaultEpoch.Data) epochData;
        mapping(bytes32 rewardId => RewardDistribution.Data) rewards;
        EnumerableSet.Bytes32Set rewardIds;
    }

    function currentEpoch(Data storage self) internal view returns (VaultEpoch.Data storage epoch) {
        return self.epochData[self.epoch];
    }

    function currentCreditCapacity(
        Data storage self,
        UD60x18 collateralPrice
    )
        internal
        view
        returns (UD60x18 totalCollateralValue)
    {
        VaultEpoch.Data storage epochData = currentEpoch(self);

        totalCollateralValue = (epochData.collateralAmounts.totalAmount()).mul(collateralPrice);
    }

    function distributeDebtToAccounts(Data storage self, SD59x18 debtChange) internal {
        currentEpoch(self).distributeDebtToAccounts(debtChange);
    }

    function consolidateAccountDebt(Data storage self, uint128 accountId) internal returns (SD59x18) {
        return currentEpoch(self).consolidateAccountDebt(accountId);
    }

    function updateRewards(
        Data storage self,
        uint128 accountId
    )
        internal
        returns (UD60x18[] memory rewards, address[] memory distributors)
    {
        rewards = new UD60x18[](self.rewardIds.length());
        distributors = new address[](self.rewardIds.length());

        uint256 numRewards = self.rewardIds.length();
        for (uint256 i = 0; i < numRewards; i++) {
            RewardDistribution.Data storage dist = self.rewards[self.rewardIds.at(i)];

            if (address(dist.distributor) == address(0)) {
                continue;
            }

            distributors[i] = address(dist.distributor);
            rewards[i] = updateReward(self, accountId, self.rewardIds.at(i));
        }
    }

    function updateReward(Data storage self, uint128 accountId, bytes32 rewardId) internal returns (UD60x18) {
        UD60x18 totalShares = ud60x18(currentEpoch(self).accountsDebtDistribution.totalShares);
        UD60x18 actorShares = currentEpoch(self).accountsDebtDistribution.getActorShares(bytes32(uint256(accountId)));

        RewardDistribution.Data storage dist = self.rewards[rewardId];

        if (address(dist.distributor) == address(0)) {
            revert Zaros_Vault_RewardDistributorNotFound();
        }

        dist.distributor.onPositionUpdated(accountId, self.collateralType, actorShares.intoUint256());

        dist.rewardPerShare += dist.updateEntry(totalShares).intoUint128();

        dist.claimStatus[accountId].pendingSend += actorShares.mul(
            ud60x18(dist.rewardPerShare).sub(ud60x18(dist.claimStatus[accountId].lastRewardPerShare))
        ).intoUint128();

        dist.claimStatus[accountId].lastRewardPerShare = dist.rewardPerShare;

        return ud60x18(dist.claimStatus[accountId].pendingSend);
    }

    function reset(Data storage self) internal {
        self.epoch++;
    }

    function currentDebt(Data storage self) internal view returns (SD59x18) {
        return currentEpoch(self).totalDebt();
    }

    function currentCollateral(Data storage self) internal view returns (UD60x18) {
        return currentEpoch(self).collateralAmounts.totalAmount();
    }

    function currentAccountCollateral(Data storage self, uint128 accountId) internal view returns (UD60x18) {
        return currentEpoch(self).getAccountCollateral(accountId);
    }
}
