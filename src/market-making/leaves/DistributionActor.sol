//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

library DistributionActor {
    struct Data {
        uint128 shares;
        int128 lastValuePerShare;
    }
}
