// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { SettlementModule } from "../modules/SettlementModule.sol";
import { Points } from "../storage/Points.sol";
import { PointsConfig } from "../storage/PointsConfig.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract SettlementModuleTestnet is SettlementModule {

    // function settleMarketOrder(
    //     uint128 accountId,
    //     uint128 marketId,
    //     address settlementFeeReceiver,
    //     bytes calldata priceData
    // )
    //     external
    //     onlyMarketOrderUpkeep(marketId)
    // {
    //     super.settleMarketOrder(accountId, marketId, settlementFeeReceiver, priceData);

    //     PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountId);
    //     address accountOwner = perpsAccount.owner;
    //     PointsConfig.Data storage pointsConfig = PointsConfig.load();
    //     Points.Data storage points = Points.load(accountOwner);
    //     // points.amount += pointsConfig.pointsPerOrder *


    // }


}
