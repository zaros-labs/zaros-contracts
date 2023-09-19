// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

library Order {
    enum OrderType {
        MARKET,
        LIMIT,
        TAKE_PROFIT,
        STOP_LOSS
    }

    struct Data {
        uint128 accountId;
        int128 initialMarginDelta;
        int128 sizeDelta;
        uint128 acceptablePrice;
        OrderType orderType;
    }
}
