// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

library SignedOrder {
    /// @notice {SignedOrder} namespace storage structure.
    /// @param tradingAccountId The trading account id that created the order offchain.
    /// @param sizeDelta The size delta of the signed order.
    /// @param targetPrice The minimum or maximum price of the signed order.
    /// @param nonce The signed index used to verify whether a given order is still valid or not.
    /// @param shouldIncreaseNonce Whether the trading account's nonce should be incremented or not.
    /// @param signature The EIP-712 encoded signature.
    struct Data {
        uint128 tradingAccountId;
        int128 sizeDelta;
        uint128 targetPrice;
        uint120 nonce;
        bool shouldIncreaseNonce;
        bytes signature;
    }
}
