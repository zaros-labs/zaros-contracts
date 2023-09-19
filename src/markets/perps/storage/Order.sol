// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

library Order {
    enum OrderType {
        MARKET,
        LIMIT,
        TAKE_PROFIT,
        STOP_LOSS
    }

    struct Payload {
        int128 initialMarginDelta;
        int128 sizeDelta;
        uint128 acceptablePrice;
        OrderType orderType;
    }

    struct Data {
        Payload payload;
        uint64 settlementTimestamp;
    }

    function reset(Data storage self) internal {
        self.payload.initialMarginDelta = 0;
        self.payload.sizeDelta = 0;
        self.payload.acceptablePrice = 0;
    }
}
