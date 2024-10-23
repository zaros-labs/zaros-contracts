// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract BtcPerpMarketCreditConfig {
    /// @notice BTC perp market credit configuration parameters.
    address internal constant BTC_PERP_MARKET_CREDIT_CONFIG_ENGINE = address(0x1);
    uint128 internal constant BTC_PERP_MARKET_CREDIT_CONFIG_ID = 1;
    uint128 internal constant BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD = 0.5e18;
    uint128 internal constant BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD = 0.6e18;
    uint128 internal constant BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE = 1e18;
    uint128 internal constant BTC_PERP_MARKET_CREDIT_CONFIG_MARKET_SHARE = 0.95e18;
    uint128 internal constant BTC_PERP_MARKET_CREDIT_CONFIG_FEE_RECIPIENTS_SHARE = 0.05e18;
}
