// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

library OcoOrder {
    struct TakeProfit {
        uint128 price;
        int128 sizeDelta;
    }

    struct StopLoss {
        uint128 price;
        int128 sizeDelta;
    }

    struct Data {
        uint128 accountId;
        TakeProfit takeProfit;
        StopLoss stopLoss;
    }
}
