// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract WBtc {
    /// @notice Margin collateral configuration parameters.
    string internal constant WBTC_NAME = "Wrapped BTC";
    string internal constant WBTC_SYMBOL = "WBTC";
    string internal constant WBTC_PRICE_ADAPTER_NAME = "WBTC/USD Zaros Price Adapter";
    string internal constant WBTC_PRICE_ADAPTER_SYMBOL = "WBTC/USD";
    uint256 internal constant WBTC_MARGIN_COLLATERAL_ID = 4;
    UD60x18 internal WBTC_DEPOSIT_CAP_X18 = ud60x18(1_000_000e18);
    uint120 internal constant WBTC_LOAN_TO_VALUE = 0.85e18;
    uint256 internal constant WBTC_MIN_DEPOSIT_MARGIN = 0.025e8;
    uint256 internal constant MOCK_WBTC_USD_PRICE = 2000e8;
    uint256 internal constant WBTC_LIQUIDATION_PRIORITY = 4;
    uint8 internal constant WBTC_DECIMALS = 8;

    // Arbitrum Sepolia
    address internal constant WBTC_ARB_SEPOLIA_ADDRESS = address(0xd9433D0E5b5Ae4593ba3880c25046BBC4dC4926C);
    address internal constant WBTC_ARB_SEPOLIA_CHAINLINK_PRICE_FEED =
        address(0xd9433D0E5b5Ae4593ba3880c25046BBC4dC4926C);
    bytes32 internal constant WBTC_USD_ARB_SEPOLIA_STREAM_ID =
        0x00039d9e45394f473ab1f050a1b963e6b05351e52d71e507509ada0c95ed75b8;
    string internal constant WBTC_USD_ARB_SEPOLIA_STREAM_ID_STRING =
        "0x00039d9e45394f473ab1f050a1b963e6b05351e52d71e507509ada0c95ed75b8";
    uint32 internal constant WBTC_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS = 86_400;

    // Monad Testnet
    address internal constant WBTC_MONAD_TESTNET_ADDRESS = address(0xd9433D0E5b5Ae4593ba3880c25046BBC4dC4926C);
    address internal constant WBTC_MONAD_TESTNET_PYTH_PRICE_FEED = address(0x2880aB155794e7179c9eE2e38200202908C17B43);
    bytes32 internal constant WBTC_MONAD_TESTNET_PYTH_PRICE_FEED_ID =
        0xc9d8b075a5c69303365ae23633d4e085199bf5c520a3b90fed1322a0342ffc33;
}
