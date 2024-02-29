// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { OrderModule } from "../modules/OrderModule.sol";
import { Points } from "../storage/Points.sol";
import { PointsConfig } from "../storage/PointsConfig.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract OrderModuleTestnet is OrderModule {
    function createMarketOrder(uint128 accountId,
        uint128 marketId,
        int128 sizeDelta,
        uint128 acceptablePrice) external override {
            super.createMarketOrder(accountId, marketId, sizeDelta, acceptablePrice);

            PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
            PointsConfig.Data storage pointsConfig = PointsConfig.load();
            Points.Data storage points = Points.load(msg.sender);

            UD60x18 indexPriceX18 = perpMarket.getIndexPrice();
            UD60x18 markPriceX18 = perpMarket.getMarkPrice(indexPriceX18, sd59x18(sizeDelta));

            uint256 accumulatedPoints = ud60x18(pontsConfig.pointsPerOrderValue).mul(sd59x18(sizeDelta).abs().intoUD60x18().mul(markPriceX18).intoUint256();
            points.amount = points.amount + accumulatedPoints;

        }

}
