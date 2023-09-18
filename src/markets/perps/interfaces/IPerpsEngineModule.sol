// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Position } from "../storage/Position.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

/// @title Perps Engine Module.
/// @notice The perps engine module is responsible by the state management of perps markets.
interface IPerpsEngineModule {
    /// @notice Returns the given perps market name.
    /// @param marketId The perps market id.
    function name(uint128 marketId) external view returns (string memory);

    /// @notice Returns the given perps market symbol.
    /// @param marketId The perps market id.
    function symbol(uint128 marketId) external view returns (string memory);

    /// @notice Returns the current market skew.
    /// @param marketId The perps market id.
    function skew(uint128 marketId) external view returns (SD59x18);

    /// @notice Returns the current market total size (longs + shorts in asset units).
    /// @param marketId The perps market id.
    function size(uint128 marketId) external view returns (UD60x18);

    /// @notice Returns the maximum total size of positions on a side of a given market.
    /// @param marketId The perps market id.
    function maxOpenInterest(uint128 marketId) external view returns (UD60x18);

    /// @notice Returns the open interest in longs and short positions in absolute size.
    /// @dev E.g: There is 500 ETH in long positions and 450 ETH in short positions, this function
    /// should return UD60x18 longsOI = 500e18 and UD60x18 shortsOI = 450e18;
    /// @param marketId The perps market id.
    /// @return longsOpenInterest The total open interest absolute size in long positions.
    /// @return shortsOpenInterest The total open interest absolute size in short positions.
    /// @return totalOpenInterest The sum of longsOpenInterest and shortsOpenInterest.
    function openInterest(uint128 marketId)
        external
        view
        returns (UD60x18 longsOpenInterest, UD60x18 shortsOpenInterest, UD60x18 totalOpenInterest);

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

    // /// @dev TODO: refactor this spaghetti code
    // function getOpenPositionData(
    //     uint256 accountId,
    //     uint128 marketId
    // )
    //     external
    //     view
    //     returns (
    //         UD60x18 notionalValue,
    //         SD59x18 size,
    //         SD59x18 unrealizedPnl,
    //         SD59x18 accruedFunding,
    //         SD59x18 netFundingPerUnit,
    //         SD59x18 nextFunding
    //     );
}
