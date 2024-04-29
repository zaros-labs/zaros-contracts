// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IPerpMarketBranch } from "../interfaces/IPerpMarketBranch.sol";
import { OrderFees } from "../leaves/OrderFees.sol";
import { Position } from "../leaves/Position.sol";
import { PerpMarket } from "../leaves/PerpMarket.sol";
import { SettlementConfiguration } from "../leaves/SettlementConfiguration.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

import { console } from "forge-std/console.sol";

/// @notice See {IPerpMarketBranch}.
contract PerpMarketBranch is IPerpMarketBranch {
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;

    /// @inheritdoc IPerpMarketBranch
    function name(uint128 marketId) external view override returns (string memory) {
        return PerpMarket.load(marketId).configuration.name;
    }

    /// @inheritdoc IPerpMarketBranch
    function symbol(uint128 marketId) external view override returns (string memory) {
        return PerpMarket.load(marketId).configuration.symbol;
    }

    /// @inheritdoc IPerpMarketBranch
    function getMaxOpenInterest(uint128 marketId) external view override returns (UD60x18) {
        return ud60x18(PerpMarket.load(marketId).configuration.maxOpenInterest);
    }

    /// @inheritdoc IPerpMarketBranch
    function getSkew(uint128 marketId) public view override returns (SD59x18) {
        return sd59x18(PerpMarket.load(marketId).skew);
    }

    /// @inheritdoc IPerpMarketBranch
    function getOpenInterest(uint128 marketId)
        external
        view
        override
        returns (UD60x18 longsOpenInterest, UD60x18 shortsOpenInterest, UD60x18 totalOpenInterest)
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        SD59x18 halfSkew = sd59x18(perpMarket.skew).div(sd59x18(2e18));
        SD59x18 currentOpenInterest = ud60x18(perpMarket.openInterest).intoSD59x18();
        SD59x18 halfOpenInterest = currentOpenInterest.div(sd59x18(2e18));
        console.log("from get open interest: ");
        // console.log(currentSkew.lt(sd59x18(0)));
        // console.log(currentSkew.abs().intoUD60x18().intoUint256());
        console.log(perpMarket.openInterest);
        console.log(halfOpenInterest.intoUD60x18().intoUint256());

        longsOpenInterest =
            halfOpenInterest.add(halfSkew).lt(SD_ZERO) ? UD_ZERO : halfOpenInterest.add(halfSkew).intoUD60x18();
        console.log("LONG OI: ");
        console.log();
        console.log(longsOpenInterest.intoUint256());
        shortsOpenInterest = unary(halfOpenInterest).add(halfSkew).abs().intoUD60x18();
        console.log(shortsOpenInterest.intoUint256());
        totalOpenInterest = longsOpenInterest.add(shortsOpenInterest);
    }

    /// @inheritdoc IPerpMarketBranch
    function getMarkPrice(
        uint128 marketId,
        uint256 indexPrice,
        int256 skewDelta
    )
        external
        view
        override
        returns (UD60x18)
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);

        return perpMarket.getMarkPrice(sd59x18(skewDelta), ud60x18(indexPrice));
    }

    /// @inheritdoc IPerpMarketBranch
    function getSettlementConfiguration(
        uint128 marketId,
        uint128 settlementConfigurationId
    )
        external
        pure
        override
        returns (SettlementConfiguration.Data memory)
    {
        return SettlementConfiguration.load(marketId, settlementConfigurationId);
    }

    /// @inheritdoc IPerpMarketBranch
    function getFundingRate(uint128 marketId) external view override returns (SD59x18) {
        return PerpMarket.load(marketId).getCurrentFundingRate();
    }

    /// @inheritdoc IPerpMarketBranch
    function getFundingVelocity(uint128 marketId) external view override returns (SD59x18) {
        return PerpMarket.load(marketId).getCurrentFundingVelocity();
    }

    /// @inheritdoc IPerpMarketBranch
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
