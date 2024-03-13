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
import { SD59x18, sd59x18, unary, ZERO as SD_ZERO, convert as sd59x18Convert } from "@prb-math/SD59x18.sol";

/// @notice See {IPerpMarketModule}.
contract PerpMarketModule is IPerpMarketModule {
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
    function getMaxOpenInterest(uint128 marketId) external view override returns (UD60x18) {
        return ud60x18(PerpMarket.load(marketId).configuration.maxOpenInterest);
    }

    /// @inheritdoc IPerpMarketModule
    function getSkew(uint128 marketId) public view override returns (SD59x18) {
        return sd59x18(PerpMarket.load(marketId).skew);
    }

    /// @inheritdoc IPerpMarketModule
    function getOpenInterest(uint128 marketId)
        external
        view
        override
        returns (UD60x18 longsOpenInterest, UD60x18 shortsOpenInterest, UD60x18 totalOpenInterest)
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        SD59x18 currentSkew = sd59x18(perpMarket.skew);
        SD59x18 currentOpenInterest = ud60x18(perpMarket.openInterest).intoSD59x18();
        SD59x18 halfOpenInterest = currentOpenInterest.div(sd59x18Convert(2));
        (longsOpenInterest, shortsOpenInterest) = (
            halfOpenInterest.add(currentSkew).intoUD60x18(),
            unary(halfOpenInterest).add(currentSkew).abs().intoUD60x18()
        );
        totalOpenInterest = longsOpenInterest.add(shortsOpenInterest);
    }

    /// @inheritdoc IPerpMarketModule
    function getMarkPrice(uint128 marketId, int256 skewDelta) external view override returns (UD60x18) {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        UD60x18 indexPriceX18 = perpMarket.getIndexPrice();

        return perpMarket.getMarkPrice(sd59x18(skewDelta), indexPriceX18);
    }

    /// @inheritdoc IPerpMarketModule
    function getSettlementConfiguration(
        uint128 marketId,
        uint128 settlementId
    )
        external
        pure
        override
        returns (SettlementConfiguration.Data memory)
    {
        return SettlementConfiguration.load(marketId, settlementId);
    }

    /// @inheritdoc IPerpMarketModule
    function getFundingRate(uint128 marketId) external view override returns (SD59x18) {
        return PerpMarket.load(marketId).getCurrentFundingRate();
    }

    /// @inheritdoc IPerpMarketModule
    function getFundingVelocity(uint128 marketId) external view override returns (SD59x18) {
        return PerpMarket.load(marketId).getCurrentFundingVelocity();
    }

    /// @inheritdoc IPerpMarketModule
    function getMarketData(uint128 marketId)
        external
        view
        returns (
            string memory name,
            string memory symbol,
            uint128 initialMarginRateX18,
            uint128 maintenanceMarginRateX18,
            uint128 maxOpenInterest,
            int128 skew,
            uint128 openInterest,
            OrderFees.Data memory orderFees
        )
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);

        name = perpMarket.configuration.name;
        symbol = perpMarket.configuration.symbol;
        initialMarginRateX18 = perpMarket.configuration.initialMarginRateX18;
        maintenanceMarginRateX18 = perpMarket.configuration.maintenanceMarginRateX18;
        maxOpenInterest = perpMarket.configuration.maxOpenInterest;
        skew = perpMarket.skew;
        openInterest = perpMarket.openInterest;
        orderFees = perpMarket.configuration.orderFees;
    }
}
