// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";

abstract contract LtcUsd {
    /// @notice LTCUSD market configuration parameters.
    uint128 internal constant LTC_USD_MARKET_ID = 9;
    string internal constant LTC_USD_MARKET_NAME = "LTCUSD Perpetual";
    string internal constant LTC_USD_MARKET_SYMBOL = "LTCUSD-PERP";
    string internal constant LTC_PRICE_ADAPTER_NAME = "LTC/USD Zaros Price Adapter";
    string internal constant LTC_PRICE_ADAPTER_SYMBOL = "LTC/USD";
    uint128 internal constant LTC_USD_IMR = 0.1e18;
    uint128 internal constant LTC_USD_MMR = 0.05e18;
    uint128 internal constant LTC_USD_MARGIN_REQUIREMENTS = LTC_USD_IMR + LTC_USD_MMR;
    uint128 internal constant LTC_USD_MAX_OI = 1_000_000e18;
    uint128 internal constant LTC_USD_MAX_SKEW = 1_000_000e18;
    uint128 internal constant LTC_USD_MAX_FUNDING_VELOCITY = 0.03e18;
    uint256 internal constant LTC_USD_SKEW_SCALE = 273_242_074e18;
    uint128 internal constant LTC_USD_MIN_TRADE_SIZE = 2e18;
    OrderFees.Data internal ltcUsdOrderFees = OrderFees.Data({ makerFee: 0.0005e18, takerFee: 0.001e18 });

    /// @notice Test only mocks
    string internal constant MOCK_LTC_USD_ARB_SEPOLIA_STREAM_ID = "MOCK_LTC_USD_ARB_SEPOLIA_STREAM_ID";
    uint256 internal constant MOCK_LTC_USD_PRICE = 85e18;

    // Arbitrum Sepolia
    address internal constant LTC_USD_ARB_SEPOLIA_CHAINLINK_PRICE_FEED =
        address(0x474c723Cd790F02BaAffA10A50fb506F8B29856b);
    uint32 internal constant LTC_USD_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARTBEATS_SECONDS = 86_400;
    bool internal constant LTC_USD_USE_CUSTOM_PRICE_ADAPTER = false;
    bytes32 internal constant LTC_USD_ARB_SEPOLIA_STREAM_ID =
        0x0003c915006ba88731510bb995c190e80b5c9cfe8cd8a19aaf00e0ed61d0b3bc;
    string internal constant STRING_LTC_USD_ARB_SEPOLIA_STREAM_ID =
        "0x0003c915006ba88731510bb995c190e80b5c9cfe8cd8a19aaf00e0ed61d0b3bc";

    // Monad Testnet
    address internal constant LTC_USD_MONAD_TESTNET_PYTH_PRICE_FEED =
        address(0x2880aB155794e7179c9eE2e38200202908C17B43);
    bytes32 internal constant LTC_USD_MONAD_TESTNET_PYTH_PRICE_FEED_ID =
        0x6e3f3fa8253588df9326580180233eb791e03b443a3ba7a1d892e73874e19a54;
}
