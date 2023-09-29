// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

library Constants {
    /// @dev Protocl wide standard decimals
    uint8 internal constant DECIMALS = 18;
    /// @dev Maximum minimum delegation time to markets
    uint32 internal constant MAX_MIN_DELEGATE_TIME = 30 days;

    /// @dev Chainlink Data Streams Lookup constants
    string internal constant DATA_STREAMS_FEED_LABEL = "feedIDs";
    string internal constant DATA_STREAMS_QUERY_LABEL = "timestamp";
    address internal constant DATA_STREAMS_FEE_ADDRESS = 0xe39Ab88f8A4777030A534146A9Ca3B52bd5D43A3;

    /// @dev All Zaros users features
    bytes32 internal constant CREATE_ACCOUNT_FEATURE_FLAG = "createAccount";
    bytes32 internal constant DEPOSIT_FEATURE_FLAG = "deposit";
    bytes32 internal constant WITHDRAW_FEATURE_FLAG = "withdraw";
    bytes32 internal constant CLAIM_FEATURE_FLAG = "claimRewards";
    bytes32 internal constant DELEGATE_FEATURE_FLAG = "delegateCollateral";

    /// @dev Zaros USD permissioned features
    bytes32 internal constant BURN_FEATURE_FLAG = "burn";
    bytes32 internal constant MINT_FEATURE_FLAG = "mint";
}
