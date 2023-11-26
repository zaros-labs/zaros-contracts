// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

/// @dev TODO: Think on refactoring this to have Order pointers being calculated
/// from the namespace (e.g load(accountId,orderId))
library Order {
    struct Payload {
        uint256 accountId;
        uint128 marketId;
        int128 initialMarginDelta;
        int128 sizeDelta;
    }

    struct Market {
        uint128 id;
        uint128 timestamp;
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
