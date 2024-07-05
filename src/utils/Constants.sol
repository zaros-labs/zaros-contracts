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
}
