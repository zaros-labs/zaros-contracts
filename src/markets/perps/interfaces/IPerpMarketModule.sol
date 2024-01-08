// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { OrderFees } from "../storage/OrderFees.sol";
import { Position } from "../storage/Position.sol";
import { SettlementConfiguration } from "../storage/SettlementConfiguration.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

/// @title Perps Engine Module.
/// @notice The perps engine module is responsible by the state management of perps markets.
interface IPerpMarketModule {
    /// @notice Returns the given perps market name.
    /// @param marketId The perps market id.
    function name(uint128 marketId) external view returns (string memory);

    /// @notice Returns the given perps market symbol.
    /// @param marketId The perps market id.
    function symbol(uint128 marketId) external view returns (string memory);

    /// @notice Returns the maximum open interest on a side of the given market.
    /// @param marketId The perps market id.
    function getMaxOpenInterest(uint128 marketId) external view returns (UD60x18);

    /// @notice Returns the current market skew.
    /// @param marketId The perps market id.
    function getSkew(uint128 marketId) external view returns (SD59x18);

    /// @notice Returns the given market's open interest, including the size of longs and shorts.
    /// @dev E.g: There is 500 ETH in long positions and 450 ETH in short positions, this function
    /// should return UD60x18 longsOpenInterest = 500e18 and UD60x18 shortsOpenInterest = 450e18;
    /// @param marketId The perps market id.
    /// @return longsOpenInterest The open interest in long positions.
    /// @return shortsOpenInterest The open interest in short positions.
    /// @return totalOpenInterest The sum of longsOpenInterest and shortsOpenInterest.
    function getOpenInterest(uint128 marketId)
        external
        view
        returns (UD60x18 longsOpenInterest, UD60x18 shortsOpenInterest, UD60x18 totalOpenInterest);

    function getMarkPrice(uint128 marketId, int256 skewDelta, uint256 indexPrice) external view returns (UD60x18);

    /// @notice Returns a Settlement Strategy used by the given market.
    /// @param marketId The perps market id.
    /// @param settlementId The perps market settlement strategy id
    function getSettlementConfiguration(
        uint128 marketId,
        uint128 settlementId
    )
        external
        view
        returns (SettlementConfiguration.Data memory);

    /// @notice Returns the given market's funding rate.
    /// @param marketId The perps market id.
    function getFundingRate(uint128 marketId) external view returns (SD59x18);

    /// @notice Returns the given market's funding velocity.
    /// @param marketId The perps market id.
    function getFundingVelocity(uint128 marketId) external view returns (SD59x18);

    /// @notice Returns the current leverage of a given account id, based on its cross margin collateral and open
    /// positions.
    /// @param accountId The trading account id.
    /// @return leverage The account leverage.
    function getAccountLeverage(uint128 accountId) external view returns (UD60x18 leverage);

    /// @notice Returns the most relevant data of the given market.
    /// @param marketId The perps market id.
    /// @return name The market name.
    /// @return symbol The market symbol.
    /// @return minInitialMarginRate The minimum initial margin rate for the market.
    /// @return maintenanceMarginRate The maintenance margin rate for the market.
    /// @return maxOpenInterest The maximum open interest for the market.
    /// @return skew The skew of the market.
    /// @return openInterest The openInterest of the market
    /// @return orderFees The configured maker and taker order fees of the market.
    function getMarketData(uint128 marketId)
        external
        view
        returns (
            string memory name,
            string memory symbol,
            uint128 minInitialMarginRate,
            uint128 maintenanceMarginRate,
            uint128 maxOpenInterest,
            int128 skew,
            uint128 openInterest,
            OrderFees.Data memory orderFees
        );
}
