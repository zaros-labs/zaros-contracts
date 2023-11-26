// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

library Order {
    struct Payload {
        uint256 accountId;
        uint128 marketId;
        int128 initialMarginDelta;
        int128 sizeDelta;
    }

    struct Market {
        uint256 timestamp;
        Payload payload;
    }

    struct Limit {
        uint128 id;
        uint128 price;
        Payload payload;
    }

    function reset(Market storage marketOrder) internal { }

    function reset(Limit storage limitOrder) internal { }
}
