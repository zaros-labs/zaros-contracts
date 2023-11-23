//SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

library RewardDistributionClaimStatus {
    struct Data {
        uint128 lastRewardPerShare;
        uint128 pendingSend;
    }
}
