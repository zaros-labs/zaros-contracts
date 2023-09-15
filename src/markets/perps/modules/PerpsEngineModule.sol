// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsEngine } from "../interfaces/IPerpsEngine.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { Position } from "../storage/Position.sol";
import { PerpsMarket } from "../storage/PerpsMarket.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

abstract contract PerpsEngineModule is IPerpsEngine {
    using PerpsMarket for PerpsMarket.Data;
    using Position for Position.Data;

    function name(uint128 marketId) external view returns (string memory) {
        return PerpsMarket.load(marketId).name;
    }

    function symbol(uint128 marketId) external view returns (string memory) {
        return PerpsMarket.load(marketId).symbol;
    }

    function skew(uint128 marketId) external view returns (SD59x18) {
        return sd59x18(PerpsMarket.load(marketId).skew);
    }

    function totalOpenInterest(uint128 marketId) external view returns (UD60x18) {
        return ud60x18(PerpsMarket.load(marketId).size);
    }

    function indexPrice(uint128 marketId) external view returns (UD60x18) {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);

        return perpsMarket.getIndexPrice();
    }

    function priceFeed(uint128 marketId) external view returns (address) {
        return PerpsMarket.load(marketId).priceFeed;
    }

    function fundingRate(uint128 marketId) external view returns (SD59x18) {
        return sd59x18(0);
    }

    function fundingVelocity(uint128 marketId) external view returns (SD59x18) {
        return sd59x18(0);
    }

    function getOpenPositionData(
        uint256 accountId,
        uint128 marketId
    )
        external
        view
        returns (
            UD60x18 notionalValue,
            SD59x18 size,
            SD59x18 pnl,
            SD59x18 accruedFunding,
            SD59x18 netFundingPerUnit,
            SD59x18 nextFunding
        )
    {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);
        Position.Data storage position = perpsMarket.positions[accountId];
        UD60x18 price = perpsMarket.getIndexPrice();

        (notionalValue, size, pnl, accruedFunding, netFundingPerUnit, nextFunding) = position.getPositionData(price);
    }
}
