//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title Tracks information per actor within a RewardDistribution.
 */
library RewardDistributionClaimStatus {
    struct Data {
        /**
         * @dev The last known reward per share for this actor.
         */
        uint128 lastRewardPerShare;
        /**
         * @dev The amount of rewards pending to be claimed by this actor.
         */
        uint128 pendingSend;
    }
}
