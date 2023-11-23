//SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

library MarketConfiguration {
    struct Data {
        address marketAddress;
        uint128 weight;
        int128 maxDebtShareValue;
    }
}
