// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";

// PRB Math dependencies
import { uMAX_UD60x18 as LIB_uMAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { uMAX_SD59x18 as LIB_uMAX_SD59x18, uMIN_SD59x18 as LIB_uMIN_SD59x18 } from "@prb-math/SD59x18.sol";

abstract contract LinkUsd {

    /// @notice LINK/USD market configuration Constants.
    uint128 internal constant LINK_USD_MARKET_ID = 3;
    string internal constant LINK_USD_MARKET_NAME = "LINK/USD Perpetual";
    string internal constant LINK_USD_MARKET_SYMBOL = "LINK/USD-PERP";
    uint128 internal constant LINK_USD_IMR = 0.05e18;
    uint128 internal constant LINK_USD_MMR = 0.025e18;
    uint128 internal constant LINK_USD_MARGIN_REQUIREMENTS = LINK_USD_IMR + LINK_USD_MMR;
    uint128 internal constant LINK_USD_MAX_OI = 100_000_000e18;
    uint256 internal constant LINK_USD_SKEW_SCALE = 2e8;
    uint128 internal constant LINK_USD_MAX_FUNDING_VELOCITY = 0.25e18;
    uint128 internal constant LINK_USD_SETTLEMENT_DELAY = 1 seconds;
    OrderFees.Data internal linkUsdOrderFees = OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 });
}
