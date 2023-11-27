// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

/// TODO: create minimum order sizeDelta per market.
library Order {
    struct Payload {
        uint128 accountId;
        uint128 marketId;
        int128 sizeDelta;
    }

    struct Market {
        uint256 timestamp;
        Payload payload;
    }

    function reset(Market storage marketOrder) internal { }
}
