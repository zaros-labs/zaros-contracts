// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";

abstract contract BtcUsd {
    /// @notice BTCUSD market configuration parameters.
    uint128 internal constant BTC_USD_MARKET_ID = 1;
    string internal constant BTC_USD_MARKET_NAME = "BTCUSD Perpetual Futures";
    string internal constant BTC_USD_MARKET_SYMBOL = "BTCUSD-PERP";
    string internal constant BTC_PRICE_ADAPTER_NAME = "BTC/USD Zaros Price Adapter";
    string internal constant BTC_PRICE_ADAPTER_SYMBOL = "BTC/USD";
    uint128 internal constant BTC_USD_IMR = 0.01e18;
    uint128 internal constant BTC_USD_MMR = 0.005e18;
    uint128 internal constant BTC_USD_MARGIN_REQUIREMENTS = BTC_USD_IMR + BTC_USD_MMR;
    uint128 internal constant BTC_USD_MAX_OI = 500_000e18;
    uint128 internal constant BTC_USD_MAX_SKEW = 500_000e18;
    uint128 internal constant BTC_USD_MAX_FUNDING_VELOCITY = 0.03e18;
    // TODO: update to mainnet value = 100_000e18.
    uint256 internal constant BTC_USD_SKEW_SCALE = 10_000_000e18;
    uint128 internal constant BTC_USD_MIN_TRADE_SIZE = 0.001e18;
    OrderFees.Data internal btcUsdOrderFees = OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 });

    /// @notice Test only mocks
    string internal constant MOCK_BTC_USD_ARB_SEPOLIA_STREAM_ID = "MOCK_BTC_USD_ARB_SEPOLIA_STREAM_ID";
    uint256 internal constant MOCK_BTC_USD_PRICE = 100_000e18;

    // Arbitrum Sepolia
    address internal constant BTC_USD_ARB_SEPOLIA_CHAINLINK_PRICE_FEED =
        address(0x56a43EB56Da12C0dc1D972ACb089c06a5dEF8e69);
    uint32 internal constant BTC_USD_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARTBEATS_SECONDS = 3600;
    bool internal constant BTC_USD_USE_CUSTOM_PRICE_ADAPTER = false;
    bytes32 internal constant BTC_USD_ARB_SEPOLIA_STREAM_ID =
        0x00037da06d56d083fe599397a4769a042d63aa73dc4ef57709d31e9971a5b439;
    string internal constant STRING_BTC_USD_ARB_SEPOLIA_STREAM_ID =
        "0x00037da06d56d083fe599397a4769a042d63aa73dc4ef57709d31e9971a5b439";

    // Monad Testnet
    address internal constant BTC_USD_MONAD_TESTNET_PYTH_PRICE_FEED =
        address(0x2880aB155794e7179c9eE2e38200202908C17B43);
    bytes32 internal constant BTC_USD_MONAD_TESTNET_PYTH_PRICE_FEED_ID =
        0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;
}
