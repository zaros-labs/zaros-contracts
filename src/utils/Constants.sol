// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

/// @notice Constants used across the protocol.
library Constants {
    /// @notice Protocol wide standard decimals.
    uint8 internal constant SYSTEM_DECIMALS = 18;
    /// @notice Maximum minimum delegation time to markets.
    uint32 internal constant MAX_MIN_DELEGATE_TIME = 30 days;
    /// @notice Default period for the proportional funding rate calculations.
    uint256 internal constant PROPORTIONAL_FUNDING_PERIOD = 1 days;
    /// @notice Default grace period for the sequencer uptime feed.
    uint256 internal constant SEQUENCER_GRACE_PERIOD_TIME = 3600;
    /// @notice EIP712 domain separator typehash.
    bytes32 internal constant CREATE_CUSTOM_ORDER_TYPEHASH = keccak256(
        "CreateCustomOrder(uint128 tradingAccountId,uint128 marketId,uint128 settlementConfigurationId,int128 sizeDelta,uint256 targetPrice)"
    );
}
