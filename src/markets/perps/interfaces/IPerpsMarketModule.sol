// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Position } from "../storage/Position.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

/// @title Perps Engine Module.
/// @notice The perps engine module is responsible by the state management of perps markets.
interface IPerpsMarketModule {
    /// @notice Returns the given perps market name.
    /// @param marketId The perps market id.
    function name(uint128 marketId) external view returns (string memory);

    /// @notice Returns the given perps market symbol.
    /// @param marketId The perps market id.
    function symbol(uint128 marketId) external view returns (string memory);

    /// @notice Returns the current market skew.
    /// @param marketId The perps market id.
    function skew(uint128 marketId) external view returns (SD59x18);

    /// @notice Returns the maximum open interest on a side of the given market.
    /// @param marketId The perps market id.
    function maxOpenInterest(uint128 marketId) external view returns (UD60x18);

    /// @notice Returns the given market's open interest, including the size of longs and shorts.
    /// @dev E.g: There is 500 ETH in long positions and 450 ETH in short positions, this function
    /// should return UD60x18 longsSize = 500e18 and UD60x18 shortsSize = 450e18;
    /// @param marketId The perps market id.
    /// @return longsSize The open interest in long positions.
    /// @return shortsSize The open interest in short positions.
    /// @return totalSize The sum of longsSize and shortsSize.
    function openInterest(uint128 marketId)
        external
        view
        returns (UD60x18 longsSize, UD60x18 shortsSize, UD60x18 totalSize);

    /// @notice Returns the current Chainlink onchain stored price for the given market id.
    /// @dev The index price returned does not necessarily match the latest price provided by the offchain
    /// Data Streams service. This means the settlement price of a trade will often be different than the index price.
    /// @param marketId The perps market id.
    function indexPrice(uint128 marketId) external view returns (UD60x18);

    /// @notice Returns the Chainlink price feed address for the given market id.
    /// @param marketId The perps market id.
    function priceFeed(uint128 marketId) external view returns (address);

    /// @notice Returns the given market's funding rate.
    /// @param marketId The perps market id.
    function fundingRate(uint128 marketId) external view returns (SD59x18);

    /// @notice Returns the given market's funding velocity.
    /// @param marketId The perps market id.
    function fundingVelocity(uint128 marketId) external view returns (SD59x18);

    /// @notice Estimates an order's fill price based on its size.
    /// @param marketId The perps market id.
    /// @param sizeDelta The order size impact on the current position.
    /// @return fillPrice The estimated order fill price.
    function estimateFillPrice(uint128 marketId, int128 sizeDelta) external view returns (UD60x18 fillPrice);

    /// @notice Returns the current leverage of an open position of the given account on the given market.
    /// @param accountId The trading account id.
    /// @param marketId The perps market id.
    /// @return leverage The position current leverage (notional value / IM).
    function getPositionLeverage(uint256 accountId, uint128 marketId) external view returns (UD60x18 leverage);

    /// @notice Gets the given market's open position details.
    /// @param accountId The perps account id.
    /// @param marketId The perps market id.
    /// @return size The position size in asset units, i.e amount of purchased contracts.
    /// @return initialMargin The notional value of the initial margin allocated by the account.
    /// @return notionalValue The notional value of the position.
    /// @return maintenanceMargin The notional value of the maintenance margin allocated by the account.
    /// @return accruedFunding The accrued funding fee.
    /// @return unrealizedPnl The current unrealized profit or loss of the position.
    function getOpenPositionData(
        uint256 accountId,
        uint128 marketId
    )
        external
        view
        returns (
            SD59x18 size,
            UD60x18 initialMargin,
            UD60x18 notionalValue,
            UD60x18 maintenanceMargin,
            SD59x18 accruedFunding,
            SD59x18 unrealizedPnl
        );
}
