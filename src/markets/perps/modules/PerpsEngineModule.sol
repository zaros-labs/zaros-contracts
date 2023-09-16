// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsEngineModule } from "../interfaces/IPerpsEngineModule.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { Position } from "../storage/Position.sol";
import { PerpsMarket } from "../storage/PerpsMarket.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

abstract contract PerpsEngineModule is IPerpsEngineModule {
    using PerpsMarket for PerpsMarket.Data;
    using Position for Position.Data;

    /// @inheritdoc IPerpsEngineModule
    function name(uint128 marketId) external view returns (string memory) {
        return PerpsMarket.load(marketId).name;
    }

    /// @inheritdoc IPerpsEngineModule
    function symbol(uint128 marketId) external view returns (string memory) {
        return PerpsMarket.load(marketId).symbol;
    }

    /// @inheritdoc IPerpsEngineModule
    function skew(uint128 marketId) external view returns (SD59x18) {
        return sd59x18(PerpsMarket.load(marketId).skew);
    }

    /// @inheritdoc IPerpsEngineModule
    function size(uint128 marketId) external view returns (UD60x18) {
        return ud60x18(PerpsMarket.load(marketId).size);
    }

    /// @inheritdoc IPerpsEngineModule
    function maxOpenInterest(uint128 marketId) external view returns (UD60x18) {
        return ud60x18(PerpsMarket.load(marketId).maxOpenInterest);
    }

    /// @notice Returns the notional value of the total open interest in longs and short positions.
    /// @param marketId The perps market id.
    /// @return longsOINotionalValue The notional value of the total open interest in long positions.
    /// @return shortsOINotionalValue The notional value of the total open interest in short positions.
    function openInterestNotionalValues(uint128 marketId)
        external
        view
        returns (UD60x18 longsOINotionalValue, UD60x18 shortsOINotionalValue)
    { }

    /// @inheritdoc IPerpsEngineModule
    function indexPrice(uint128 marketId) external view returns (UD60x18) {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);

        return perpsMarket.getIndexPrice();
    }

    /// @inheritdoc IPerpsEngineModule
    function priceFeed(uint128 marketId) external view returns (address) {
        return PerpsMarket.load(marketId).priceFeed;
    }

    /// @inheritdoc IPerpsEngineModule
    function fundingRate(uint128 marketId) external view returns (SD59x18) {
        return sd59x18(0);
    }

    /// @inheritdoc IPerpsEngineModule
    function fundingVelocity(uint128 marketId) external view returns (SD59x18) {
        return sd59x18(0);
    }

    /// @inheritdoc IPerpsEngineModule
    // function getOpenPositionData(
    //     uint256 accountId,
    //     uint128 marketId
    // )
    //     external
    //     view
    //     returns (
    //         UD60x18 notionalValue,
    //         SD59x18 size,
    //         SD59x18 pnl,
    //         SD59x18 accruedFunding,
    //         SD59x18 netFundingPerUnit,
    //         SD59x18 nextFunding
    //     )
    // {
    //     PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);
    //     Position.Data storage position = perpsMarket.positions[accountId];
    //     UD60x18 price = perpsMarket.getIndexPrice();

    //     (notionalValue, size, pnl, accruedFunding, netFundingPerUnit, nextFunding) = position.getPositionData(price);
    // }
}
