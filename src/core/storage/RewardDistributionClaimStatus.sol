//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title Tracks information per actor within a RewardDistribution.
 */
library RewardDistributionClaimStatus {
    struct Data {
        uint128 lastRewardPerShare;
        uint128 pendingSend;
    }
}
