// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract WEth {
    /// @notice Margin collateral configuration parameters.
    string internal constant WETH_NAME = "Wrapped Ether";
    string internal constant WETH_SYMBOL = "WETH";
    string internal constant WETH_PRICE_ADAPTER_NAME = "WETH/USD Zaros Price Adapter";
    string internal constant WETH_PRICE_ADAPTER_SYMBOL = "WETH/USD";
    uint256 internal constant WETH_MARGIN_COLLATERAL_ID = 3;
    UD60x18 internal WETH_DEPOSIT_CAP_X18 = ud60x18(1_000_000e18);
    uint120 internal constant WETH_LOAN_TO_VALUE = 0.85e18;
    uint256 internal constant WETH_MIN_DEPOSIT_MARGIN = 0.025e18;
    uint256 internal constant MOCK_WETH_USD_PRICE = 2000e18;
    uint256 internal constant WETH_LIQUIDATION_PRIORITY = 3;
    uint8 internal constant WETH_DECIMALS = 18;

    // Arbitrum Sepolia
    address internal constant WETH_ARB_SEPOLIA_ADDRESS = address(0xd9433D0E5b5Ae4593ba3880c25046BBC4dC4926C);
    address internal constant WETH_ARB_SEPOLIA_CHAINLINK_PRICE_FEED =
        address(0xd9433D0E5b5Ae4593ba3880c25046BBC4dC4926C);
    bytes32 internal constant WETH_USD_ARB_SEPOLIA_STREAM_ID =
        0x000362205e10b3a147d02792eccee483dca6c7b44ecce7012cb8c6e0b68b3ae9;
    string internal constant WETH_USD_ARB_SEPOLIA_STREAM_ID_STRING =
        "0x000362205e10b3a147d02792eccee483dca6c7b44ecce7012cb8c6e0b68b3ae9";
    uint32 internal constant WETH_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS = 86_400;

    // Monad Testnet
    address internal constant WETH_MONAD_TESTNET_ADDRESS = address(0xd9433D0E5b5Ae4593ba3880c25046BBC4dC4926C);
    address internal constant WETH_MONAD_TESTNET_PYTH_PRICE_FEED = address(0x2880aB155794e7179c9eE2e38200202908C17B43);
    bytes32 internal constant WETH_MONAD_TESTNET_PYTH_PRICE_FEED_ID =
        0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6;
}
