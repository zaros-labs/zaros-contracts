// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

library OcoOrder {
    struct TakeProfit {
        uint128 price;
    }

    struct StopLoss {
        uint128 price;
    }

    struct Data {
        TakeProfit takeProfit;
        StopLoss stopLoss;
    }
}
