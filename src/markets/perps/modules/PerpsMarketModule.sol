// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IPerpsMarketModule } from "../interfaces/IPerpsMarketModule.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { Position } from "../storage/Position.sol";
import { PerpsMarket } from "../storage/PerpsMarket.sol";
import { SettlementStrategy } from "../storage/SettlementStrategy.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

/// @notice See {IPerpsMarketModule}.
abstract contract PerpsMarketModule is IPerpsMarketModule {
    using PerpsMarket for PerpsMarket.Data;
    using Position for Position.Data;

    /// @inheritdoc IPerpsMarketModule
    function name(uint128 marketId) external view override returns (string memory) {
        return PerpsMarket.load(marketId).name;
    }

    /// @inheritdoc IPerpsMarketModule
    function symbol(uint128 marketId) external view override returns (string memory) {
        return PerpsMarket.load(marketId).symbol;
    }

    /// @inheritdoc IPerpsMarketModule
    function skew(uint128 marketId) public view override returns (SD59x18) {
        return sd59x18(PerpsMarket.load(marketId).skew);
    }

    /// @inheritdoc IPerpsMarketModule
    function maxOpenInterest(uint128 marketId) external view override returns (UD60x18) {
        return ud60x18(PerpsMarket.load(marketId).maxOpenInterest);
    }

    /// @inheritdoc IPerpsMarketModule
    function openInterest(uint128 marketId)
        external
        view
        override
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

    /// @inheritdoc IPerpsMarketModule
    function indexPrice(uint128 marketId) external view override returns (UD60x18) {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);

        return perpsMarket.getIndexPrice();
    }

    /// @inheritdoc IPerpsMarketModule
    function settlementStrategy(uint128 marketId) external view override returns (SettlementStrategy.Data memory) {
        return PerpsMarket.load(marketId).settlementStrategy;
    }

    /// @inheritdoc IPerpsMarketModule
    function fundingRate(uint128 marketId) external view override returns (SD59x18) {
        return PerpsMarket.load(marketId).getCurrentFundingRate();
    }

    /// @inheritdoc IPerpsMarketModule
    function fundingVelocity(uint128 marketId) external view override returns (SD59x18) {
        return PerpsMarket.load(marketId).getCurrentFundingVelocity();
    }

    /// @inheritdoc IPerpsMarketModule
    function estimateFillPrice(uint128 marketId, int128 sizeDelta) external view override returns (UD60x18 fillPrice) {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);
        fillPrice = perpsMarket.getIndexPrice();
    }

    function getPositionLeverage(uint256 accountId, uint128 marketId) external view override returns (UD60x18) {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);
        Position.Data storage position = perpsMarket.positions[accountId];

        UD60x18 marketIndexPrice = perpsMarket.getIndexPrice();
        UD60x18 leverage = position.getNotionalValue(marketIndexPrice).div(ud60x18(position.initialMargin));
    }

    /// @inheritdoc IPerpsMarketModule
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
            uint128 size,
            OrderFees.Data memory orderFees,
            SettlementStrategy.Data memory settlementStrategy
        )
    {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);

        name = perpsMarket.name;
        symbol = perpsMarket.symbol;
        minInitialMarginRate = perpsMarket.minInitialMarginRate;
        maintenanceMarginRate = perpsMarket.maintenanceMarginRate;
        maxOpenInterest = perpsMarket.maxOpenInterest;
        skew = perpsMarket.skew;
        size = perpsMarket.size;
        orderFees = perpsMarket.orderFees;
        settlementStrategy = perpsMarket.settlementStrategy;
    }

    /// @inheritdoc IPerpsMarketModule
    function getOpenPositionData(
        uint256 accountId,
        uint128 marketId
    )
        external
        view
        override
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
