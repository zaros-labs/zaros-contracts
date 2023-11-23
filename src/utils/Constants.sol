// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

library Constants {
    /// @notice Protocol wide standard decimals.
    uint8 internal constant SYSTEM_DECIMALS = 18;
    /// @notice Maximum minimum delegation time to markets.
    uint32 internal constant MAX_MIN_DELEGATE_TIME = 30 days;

    /// @notice Chainlink Data Streams Lookup constants.
    string internal constant DATA_STREAMS_FEED_LABEL = "feedIDs";
    string internal constant DATA_STREAMS_QUERY_LABEL = "timestamp";
    // TODO: remove both stream ids constants.
    string internal constant DATA_STREAMS_ETH_USD_STREAM_ID =
        "0x00029584363bcf642315133c335b3646513c20f049602fc7d933be0d3f6360d3";
    string internal constant DATA_STREAMS_LINK_USD_STREAM_ID =
        "0x0002191c50b7bdaf2cb8672453141946eea123f8baeaa8d2afa4194b6955e683";
    address internal constant DATA_STREAMS_FEE_ADDRESS = 0xe39Ab88f8A4777030A534146A9Ca3B52bd5D43A3;

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
