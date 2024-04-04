// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";

// PRB Math dependencies
import { uMAX_UD60x18 as LIB_uMAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { uMAX_SD59x18 as LIB_uMAX_SD59x18, uMIN_SD59x18 as LIB_uMIN_SD59x18 } from "@prb-math/SD59x18.sol";

abstract contract EthUsd {
    /// @notice ETH/USD market configuration parameters.
    uint128 internal constant ETH_USD_MARKET_ID = 2;
    string internal constant ETH_USD_MARKET_NAME = "ETH/USD Perpetual Futures";
    string internal constant ETH_USD_MARKET_SYMBOL = "ETH/USD PERP";
    uint128 internal constant ETH_USD_IMR = 0.005e18;
    uint128 internal constant ETH_USD_MMR = 0.005e18;
    uint128 internal constant ETH_USD_MARGIN_REQUIREMENTS = ETH_USD_IMR + ETH_USD_MMR;
    uint128 internal constant ETH_USD_MAX_OI = 100_000e18;
    uint128 internal constant ETH_USD_MAX_FUNDING_VELOCITY = 0.025e18;
    uint256 internal constant ETH_USD_SKEW_SCALE = 1_000_000e18;
    uint256 internal constant ETH_USD_MIN_TRADE_SIZE = 0.05e18;
    uint128 internal constant ETH_USD_SETTLEMENT_DELAY = 1 seconds;
    bool internal constant ETH_USD_IS_PREMIUM_FEED = false;
    OrderFees.Data internal ethUsdOrderFees = OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 });

    /// @notice Test only mocks
    string internal constant MOCK_ETH_USD_STREAM_ID = "MOCK_ETH_USD_STREAM_ID";
    uint256 internal constant MOCK_ETH_USD_PRICE = 1000e18;
}
