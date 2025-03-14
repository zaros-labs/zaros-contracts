// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract UsdToken {
    /// @notice Margin collateral configuration parameters.
    string internal constant USD_TOKEN_NAME = "Zaros Perpetuals AMM USD";
    string internal constant USD_TOKEN_SYMBOL = "USDz";
    string internal constant USD_TOKEN_PRICE_ADAPTER_NAME = "USDz/USD Zaros Price Adapter";
    string internal constant USD_TOKEN_PRICE_ADAPTER_SYMBOL = "USDz/USD";
    uint256 internal constant USD_TOKEN_MARGIN_COLLATERAL_ID = 1;
    UD60x18 internal USD_TOKEN_DEPOSIT_CAP_X18 = ud60x18(50_000_000_000e18);
    uint120 internal constant USD_TOKEN_LOAN_TO_VALUE = 1e18;
    uint256 internal constant USD_TOKEN_MIN_DEPOSIT_MARGIN = 50e18;
    uint256 internal constant MOCK_USD_TOKEN_USD_PRICE = 1e18;
    uint256 internal constant USD_TOKEN_LIQUIDATION_PRIORITY = 1;
    uint8 internal constant USD_TOKEN_DECIMALS = 18;
    uint32 internal constant USD_TOKEN_ARB_SEPOLIA_CHAINLINK_PRICE_FEED_HEARBEAT_SECONDS = 86_400;

    // Arbitrum Sepolia
    address internal constant USD_TOKEN_ARB_SEPOLIA_ADDRESS = address(0x8648d10fE74dD9b4B454B4db9B63b03998c087Ba);
    address internal constant USD_TOKEN_ARB_SEPOLIA_CHAINLINK_PRICE_FEED =
        address(0x80EDee6f667eCc9f63a0a6f55578F870651f06A4);

    // Monad Testnet
    address internal constant USD_TOKEN_MONAD_TESTNET_ADDRESS = address(0xbaDF69305038a4E009f79416340B7f4Bc5ea7a6b);
    address internal constant USD_TOKEN_MONAD_TESTNET_PYTH_PRICE_FEED =
        address(0x2880aB155794e7179c9eE2e38200202908C17B43);
    bytes32 internal constant USD_TOKEN_MONAD_TESTNET_PYTH_PRICE_FEED_ID =
        0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
}
