// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { RewardDistributor } from "./RewardDistributor.sol";

/// TODO: implement
contract AsyncRewardDistributor is RewardDistributor {
    constructor(
        address rewardManager_,
        address rewardToken_,
        string memory name_
    )
        RewardDistributor(rewardManager_, rewardToken_, name_)
    { }
}
