// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract BtcMarketDebt {
    /// @notice BTC market debt configuration parameters.
    uint128 internal constant BTC_MARKET_DEBT_ID = 1;
    uint128 internal constant BTC_MARKET_DEBT_AUTO_DELEVERAGE_START_THRESHOLD = 0.5e18;
    uint128 internal constant BTC_MARKET_DEBT_AUTO_DELEVERAGE_END_THRESHOLD = 0.6e18;
    uint128 internal constant BTC_MARKET_DEBT_AUTO_DELEVERAGE_POWER_SCALE = 1e18;
    uint128 internal constant BTC_MARKET_DEBT_MARKET_SHARE = 0.95e18;
    uint128 internal constant BTC_MARKET_DEBT_FEE_RECIPIENTS_SHARE = 0.05e18;
}
