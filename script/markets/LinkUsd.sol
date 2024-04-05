// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";

// PRB Math dependencies
import { uMAX_UD60x18 as LIB_uMAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { uMAX_SD59x18 as LIB_uMAX_SD59x18, uMIN_SD59x18 as LIB_uMIN_SD59x18 } from "@prb-math/SD59x18.sol";

abstract contract LinkUsd {
    /// @notice LINK/USD market configuration parameters.
    uint128 internal constant LINK_USD_MARKET_ID = 3;
    string internal constant LINK_USD_MARKET_NAME = "LINK/USD Perpetual";
    string internal constant LINK_USD_MARKET_SYMBOL = "LINK/USD-PERP";
    uint128 internal constant LINK_USD_IMR = 0.05e18;
    uint128 internal constant LINK_USD_MMR = 0.025e18;
    uint128 internal constant LINK_USD_MARGIN_REQUIREMENTS = LINK_USD_IMR + LINK_USD_MMR;
    uint128 internal constant LINK_USD_MAX_OI = 100_000_000e18;
    uint128 internal constant LINK_USD_MAX_FUNDING_VELOCITY = 0.25e18;
    uint256 internal constant LINK_USD_SKEW_SCALE = 1_151_243_152e18;
    uint256 internal constant LINK_USD_MIN_TRADE_SIZE = 5e18;
    uint248 internal constant LINK_USD_SETTLEMENT_DELAY = 1 seconds;
    bool internal constant LINK_USD_IS_PREMIUM_FEED = false;
    OrderFees.Data internal linkUsdOrderFees = OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 });

    /// @notice Test only mocks
    string internal constant MOCK_LINK_USD_STREAM_ID = "MOCK_LINK_USD_STREAM_ID";
    uint256 internal constant MOCK_LINK_USD_PRICE = 10e18;

    // TODO: Update address value
    address internal constant LINK_USD_PRICE_FEED = address(0x20);

    // TODO: Update stream id value
    string internal constant LINK_USD_STREAM_ID = "stream-id";
}
