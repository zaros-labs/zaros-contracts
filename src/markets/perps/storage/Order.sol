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
        uint128 acceptablePrice;
    }

    struct Data {
        uint8 id;
        uint248 timestamp;
        Payload payload;
    }

    /// @dev TODO: should we just update account id to 0?
    function reset(Data storage self) internal {
        self.payload.accountId = 0;
        self.payload.marketId = 0;
        self.payload.initialMarginDelta = 0;
        self.payload.sizeDelta = 0;
        self.payload.acceptablePrice = 0;
        self.timestamp = 0;
    }
}
