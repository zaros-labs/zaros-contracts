// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

/// @dev TODO: Think on refactoring this to have Order pointers being calculated
/// from the namespace (e.g load(accountId,orderId))
library Order {
    /// @notice Supported types of orders.
    enum OrderType {
        MARKET,
        LIMIT,
        TAKE_PROFIT,
        STOP_LOSS
    }

    struct Payload {
        uint128 accountId;
        uint128 marketId;
        int128 initialMarginDelta;
        int128 sizeDelta;
        uint128 acceptablePrice;
        OrderType orderType;
    }

    struct Data {
        Payload payload;
        uint256 settlementTimestamp;
    }

    function reset(Data storage self) internal {
        self.payload.initialMarginDelta = 0;
        self.payload.sizeDelta = 0;
        self.payload.acceptablePrice = 0;
    }
}
