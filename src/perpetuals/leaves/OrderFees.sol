// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

/// @title The OrderFees namespace.
library OrderFees {
    /// @notice {OrderFees} namespace storage structure.
    /// @param makerFee The order maker fee value applied.
    /// @param takerFee The order taker fee value applied.
    struct Data {
        int128 makerFee;
        int128 takerFee;
    }
}
