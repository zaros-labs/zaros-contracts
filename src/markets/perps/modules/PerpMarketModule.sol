// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IPerpMarketModule } from "../interfaces/IPerpMarketModule.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { Position } from "../storage/Position.sol";
import { PerpMarket } from "../storage/PerpMarket.sol";
import { SettlementConfiguration } from "../storage/SettlementConfiguration.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

/// @notice See {IPerpMarketModule}.
abstract contract PerpMarketModule is IPerpMarketModule {
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;

    /// @inheritdoc IPerpMarketModule
    function name(uint128 marketId) external view override returns (string memory) {
        return PerpMarket.load(marketId).configuration.name;
    }

    /// @inheritdoc IPerpMarketModule
    function symbol(uint128 marketId) external view override returns (string memory) {
        return PerpMarket.load(marketId).configuration.symbol;
    }

    /// @inheritdoc IPerpMarketModule
    function maxOpenInterest(uint128 marketId) external view override returns (UD60x18) {
        return ud60x18(PerpMarket.load(marketId).configuration.maxOpenInterest);
    }

    /// @inheritdoc IPerpMarketModule
    function skew(uint128 marketId) public view override returns (SD59x18) {
        return sd59x18(PerpMarket.load(marketId).skew);
    }

    /// @inheritdoc IPerpMarketModule
    function openInterest(uint128 marketId)
        external
        view
        override
        returns (UD60x18 longsSize, UD60x18 shortsSize, UD60x18 totalSize)
    {
        SD59x18 currentSkew = skew(marketId);
        SD59x18 currentOpenInterest = ud60x18(PerpMarket.load(marketId).size).intoSD59x18();
        SD59x18 halfOpenInterest = currentOpenInterest.div(sd59x18(2));
        (longsSize, shortsSize) = (
            halfOpenInterest.add(currentSkew).intoUD60x18(),
            unary(halfOpenInterest).add(currentSkew).abs().intoUD60x18()
        );
        totalSize = longsSize.add(shortsSize);
    }

    /// @inheritdoc IPerpMarketModule
    function markPrice(
        uint128 marketId,
        int256 skewDelta,
        uint256 indexPrice
    )
        external
        view
        override
        returns (UD60x18)
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);

        return perpMarket.getMarkPrice(sd59x18(skewDelta), ud60x18(indexPrice));
    }

    /// @inheritdoc IPerpMarketModule
    function getSettlementConfiguration(
        uint128 marketId,
        uint128 settlementId
    )
        external
        view
        override
        returns (SettlementConfiguration.Data memory)
    {
        return SettlementConfiguration.load(marketId, settlementId);
    }

    /// @inheritdoc IPerpMarketModule
    function fundingRate(uint128 marketId) external view override returns (SD59x18) {
        return PerpMarket.load(marketId).getCurrentFundingRate();
    }

    /// @inheritdoc IPerpMarketModule
    function fundingVelocity(uint128 marketId) external view override returns (SD59x18) {
        return PerpMarket.load(marketId).getCurrentFundingVelocity();
    }

    /// @inheritdoc IPerpMarketModule
    function getAccountLeverage(uint128 accountId) external view override returns (UD60x18) { }

    /// @inheritdoc IPerpMarketModule
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
            OrderFees.Data memory orderFees
        )
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);

        name = perpMarket.configuration.name;
        symbol = perpMarket.configuration.symbol;
        minInitialMarginRate = perpMarket.configuration.minInitialMarginRate;
        maintenanceMarginRate = perpMarket.configuration.maintenanceMarginRate;
        maxOpenInterest = perpMarket.configuration.maxOpenInterest;
        skew = perpMarket.skew;
        size = perpMarket.size;
        orderFees = perpMarket.configuration.orderFees;
    }

    /// @inheritdoc IPerpMarketModule
    function getOpenPositionData(
        uint128 accountId,
        uint128 marketId,
        uint256 indexPrice
    )
        external
        view
        override
        returns (
            SD59x18 size,
            UD60x18 notionalValue,
            UD60x18 maintenanceMargin,
            SD59x18 accruedFunding,
            SD59x18 unrealizedPnl
        )
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        Position.Data storage position = Position.load(accountId, marketId);

        // UD60x18 maintenanceMarginRate = ud60x18(perpMarket.maintenanceMarginRate);
        UD60x18 price = perpMarket.getMarkPrice(SD_ZERO, ud60x18(indexPrice));
        SD59x18 fundingRate = perpMarket.getCurrentFundingRate();
        SD59x18 fundingFeePerUnit = perpMarket.calculateNextFundingFeePerUnit(fundingRate, price);

        (size, notionalValue, maintenanceMargin, accruedFunding, unrealizedPnl) = position.getPositionData(
            ud60x18(perpMarket.configuration.maintenanceMarginRate), price, fundingFeePerUnit
        );
    }
}
