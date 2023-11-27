// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

/// TODO: create minimum order sizeDelta per market.
library Order {
    string internal constant LIMIT_ORDER_DOMAIN = "fi.zaros.markets.perps.Order.Limit";

    struct Payload {
        uint128 accountId;
        uint128 marketId;
        int128 sizeDelta;
    }

    struct Market {
        uint256 timestamp;
        Payload payload;
    }

    function load(uint128 accountId, uint128 limitOrderId) internal pure returns (Limit storage limitOrder) {
        bytes32 slot = keccak256(abi.encode(LIMIT_ORDER_DOMAIN, accountId, limitOrderId));
        assembly {
            limitOrder.slot := slot
        }
    }

    function createLimit(uint128 id, uint256 price, Payload memory payload) internal returns (uint256 limitOrderSlot) {
        Limit storage limitOrder = load(payload.accountId, id);

        limitOrder.price = price;
        limitOrder.payload = payload;
    }

    function reset(Market storage marketOrder) internal { }

    function reset(Limit storage limitOrder) internal { }
}
