// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";

abstract contract MaticUsd {
    /// @notice MATICUSD market configuration parameters.
    uint128 internal constant MATIC_USD_MARKET_ID = 8;
    string internal constant MATIC_USD_MARKET_NAME = "MATICUSD Perpetual";
    string internal constant MATIC_USD_MARKET_SYMBOL = "MATICUSD-PERP";
    string internal constant MATIC_PRICE_ADAPTER_NAME = "MATIC/USD Zaros Price Adapter";
    string internal constant MATIC_PRICE_ADAPTER_SYMBOL = "MATIC/USD";
    uint128 internal constant MATIC_USD_IMR = 0.1e18;
    uint128 internal constant MATIC_USD_MMR = 0.05e18;
    uint128 internal constant MATIC_USD_MARGIN_REQUIREMENTS = MATIC_USD_IMR + MATIC_USD_MMR;
    uint128 internal constant MATIC_USD_MAX_OI = 500_000_000e18;
    uint128 internal constant MATIC_USD_MAX_SKEW = 500_000_000e18;
    uint128 internal constant MATIC_USD_MAX_FUNDING_VELOCITY = 0.03e18;
    uint256 internal constant MATIC_USD_SKEW_SCALE = 64_381_888_511e18;
    uint128 internal constant MATIC_USD_MIN_TRADE_SIZE = 300e18;
    OrderFees.Data internal maticUsdOrderFees = OrderFees.Data({ makerFee: 0.0005e18, takerFee: 0.001e18 });

    /// @notice Test only mocks
    string internal constant MOCK_MATIC_USD_ARB_SEPOLIA_STREAM_ID = "MOCK_MATIC_USD_ARB_SEPOLIA_STREAM_ID";
    uint256 internal constant MOCK_MATIC_USD_PRICE = 0.71e18;

    // Arbitrum Sepolia
    address internal constant MATIC_USD_ARB_SEPOLIA_CHAINLINK_PRICE_FEED =
        address(0x44a502d94c47f47aC6D65ebdFDf4c39500e72491);
    uint32 internal constant MATIC_USD_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARTBEATS_SECONDS = 86_400;
    bool internal constant MATIC_USD_USE_CUSTOM_PRICE_ADAPTER = false;
    bytes32 internal constant MATIC_USD_ARB_SEPOLIA_STREAM_ID =
        0x0003fd6ff25e1a28ddd55c85882279987be478a66a75abdf05a468beb5b8b467;
    string internal constant STRING_MATIC_USD_ARB_SEPOLIA_STREAM_ID =
        "0x0003fd6ff25e1a28ddd55c85882279987be478a66a75abdf05a468beb5b8b467";

    // Monad Testnet
    address internal constant MATIC_USD_MONAD_TESTNET_PYTH_PRICE_FEED =
        address(0x2880aB155794e7179c9eE2e38200202908C17B43);
    bytes32 internal constant MATIC_USD_MONAD_TESTNET_PYTH_PRICE_FEED_ID =
        0xffd11c5a1cfd42f80afb2df4d9f264c15f956d68153335374ec10722edd70472;
}
