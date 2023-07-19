// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// TODO: use feature flag constants from here
library Constants {
    /// @dev Protocl wide standard decimals
    uint8 internal constant DECIMALS = 18;
    /// @dev Maximum minimum delegation time to markets
    uint32 internal constant MAX_MIN_DELEGATE_TIME = 30 days;

    /// @dev All users features

    bytes32 internal constant CREATE_ACCOUNT_FEATURE_FLAG = "createAccount";
    bytes32 internal constant DEPOSIT_FEATURE_FLAG = "deposit";
    bytes32 internal constant WITHDRAW_FEATURE_FLAG = "withdraw";
    bytes32 internal constant CLAIM_FEATURE_FLAG = "claimRewards";
    bytes32 internal constant DELEGATE_FEATURE_FLAG = "delegateCollateral";

    /// @dev Permissioned fetures
    bytes32 internal constant MARKET_FEATURE_FLAG = "configureMarkets";
    bytes32 internal constant STRATEGY_FEATURE_FLAG = "registerStrategy";
}
