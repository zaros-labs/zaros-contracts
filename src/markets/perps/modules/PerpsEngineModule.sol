// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsEngineModule } from "../interfaces/IPerpsEngineModule.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { Position } from "../storage/Position.sol";
import { PerpsMarket } from "../storage/PerpsMarket.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

/// @notice See {IPerpsEngineModule}.
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
    function skew(uint128 marketId) public view returns (SD59x18) {
        return sd59x18(PerpsMarket.load(marketId).skew);
    }

    /// @inheritdoc IPerpsEngineModule
    function maxOpenInterest(uint128 marketId) external view returns (UD60x18) {
        return ud60x18(PerpsMarket.load(marketId).maxOpenInterest);
    }

    /// @inheritdoc IPerpsEngineModule
    function openInterest(uint128 marketId)
        external
        view
        returns (UD60x18 longsSize, UD60x18 shortsSize, UD60x18 totalSize)
    {
        SD59x18 currentSkew = skew(marketId);
        SD59x18 currentOpenInterest = ud60x18(PerpsMarket.load(marketId).size).intoSD59x18();
        SD59x18 halfOpenInterest = currentOpenInterest.div(sd59x18(2));
        (longsSize, shortsSize) = (
            halfOpenInterest.add(currentSkew).intoUD60x18(),
            unary(halfOpenInterest).add(currentSkew).abs().intoUD60x18()
        );
        totalSize = longsSize.add(shortsSize);
    }

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
        return PerpsMarket.load(marketId).getCurrentFundingRate();
    }

    /// @inheritdoc IPerpsEngineModule
    function fundingVelocity(uint128 marketId) external view returns (SD59x18) {
        return PerpsMarket.load(marketId).getCurrentFundingVelocity();
    }

    /// @inheritdoc IPerpsEngineModule
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
        )
    {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);
        Position.Data storage position = perpsMarket.positions[accountId];

        // UD60x18 maintenanceMarginRate = ud60x18(perpsMarket.maintenanceMarginRate);
        UD60x18 price = perpsMarket.getIndexPrice();
        SD59x18 fundingFeePerUnit = perpsMarket.calculateNextFundingFeePerUnit(price);

        (size, initialMargin, notionalValue, maintenanceMargin, accruedFunding, unrealizedPnl) =
            position.getPositionData(ud60x18(perpsMarket.maintenanceMarginRate), price, fundingFeePerUnit);
    }
}
