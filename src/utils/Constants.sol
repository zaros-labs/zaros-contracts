// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

/// @notice Constants used across the protocol.
library Constants {
    /// @notice Protocol wide standard decimals.
    uint8 internal constant SYSTEM_DECIMALS = 18;
    /// @notice Maximum minimum delegation time to markets.
    uint32 internal constant MAX_MIN_DELEGATE_TIME = 30 days;
    /// @notice Default period for the proportional funding rate calculations.
    uint256 internal constant FUNDING_INTERVAL = 1 days;
    /// @notice EIP-2535 address used to indetify a multi delegate call.
    address internal constant MULTI_INIT_ADDRESS = 0xD1a302d1A302d1A302d1A302d1A302D1A302D1a3;

    /// @notice Feature flags for all permissionless features.
    bytes32 internal constant CREATE_ACCOUNT_FEATURE_FLAG = "createAccount";
    bytes32 internal constant DEPOSIT_FEATURE_FLAG = "deposit";
    bytes32 internal constant WITHDRAW_FEATURE_FLAG = "withdraw";
    bytes32 internal constant CLAIM_FEATURE_FLAG = "claimRewards";
    bytes32 internal constant DELEGATE_FEATURE_FLAG = "delegateCollateral";

    /// @notice Zaros USD permissioned features.
    bytes32 internal constant BURN_FEATURE_FLAG = "burn";
    bytes32 internal constant MINT_FEATURE_FLAG = "mint";
}
