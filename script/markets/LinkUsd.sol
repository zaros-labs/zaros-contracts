// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";

abstract contract LinkUsd {
    /// @notice LINKUSD market configuration parameters.
    uint128 internal constant LINK_USD_MARKET_ID = 3;
    string internal constant LINK_USD_MARKET_NAME = "LINKUSD Perpetual";
    string internal constant LINK_USD_MARKET_SYMBOL = "LINKUSD-PERP";
    string internal constant LINK_PRICE_ADAPTER_NAME = "LINK/USD Zaros Price Adapter";
    string internal constant LINK_PRICE_ADAPTER_SYMBOL = "LINK/USD";
    uint128 internal constant LINK_USD_IMR = 0.05e18;
    uint128 internal constant LINK_USD_MMR = 0.025e18;
    uint128 internal constant LINK_USD_MARGIN_REQUIREMENTS = LINK_USD_IMR + LINK_USD_MMR;
    uint128 internal constant LINK_USD_MAX_OI = 100_000_000e18;
    uint128 internal constant LINK_USD_MAX_SKEW = 100_000_000e18;
    uint128 internal constant LINK_USD_MAX_FUNDING_VELOCITY = 0.03e18;
    uint256 internal constant LINK_USD_SKEW_SCALE = 1_151_243_152e18;
    uint128 internal constant LINK_USD_MIN_TRADE_SIZE = 5e18;
    OrderFees.Data internal linkUsdOrderFees = OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 });

    /// @notice Test only mocks
    string internal constant MOCK_LINK_USD_ARB_SEPOLIA_STREAM_ID = "MOCK_LINK_USD_ARB_SEPOLIA_STREAM_ID";
    uint256 internal constant MOCK_LINK_USD_PRICE = 10e18;

    // TODO: Update address value
    address internal constant LINK_USD_ARB_SEPOLIA_CHAINLINK_PRICE_FEED =
        address(0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298);
    uint32 internal constant LINK_USD_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARTBEATS_SECONDS = 3600;
    bool internal constant LINK_USD_USE_CUSTOM_PRICE_ADAPTER = false;

    // Arbitrum Sepolia
    bytes32 internal constant LINK_USD_ARB_SEPOLIA_STREAM_ID =
        0x00036fe43f87884450b4c7e093cd5ed99cac6640d8c2000e6afc02c8838d0265;
    string internal constant STRING_LINK_USD_ARB_SEPOLIA_STREAM_ID =
        "0x00036fe43f87884450b4c7e093cd5ed99cac6640d8c2000e6afc02c8838d0265";

    // Monad Testnet
    address internal constant LINK_USD_MONAD_TESTNET_PYTH_PRICE_FEED =
        address(0x2880aB155794e7179c9eE2e38200202908C17B43);
    bytes32 internal constant LINK_USD_MONAD_TESTNET_PYTH_PRICE_FEED_ID =
        0x8ac0c70fff57e9aefdf5edf44b51d62c2d433653cbb2cf5cc06bb115af04d221;
}
