// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { GlobalConfiguration } from "../storage/GlobalConfiguration.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { PerpMarket } from "../storage/PerpMarket.sol";
import { Position } from "../storage/Position.sol";
import { MarketOrder } from "../storage/MarketOrder.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

contract LiquidationModule {
    using EnumerableSet for EnumerableSet.UintSet;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using PerpsAccount for PerpsAccount.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;
    using MarketOrder for MarketOrder.Data;
    using SafeCast for uint256;

    // TODO: Implement
    modifier onlyRegisteredLiquidator() {
        _;
    }

    function checkLiquidatableAccounts(uint128[] calldata accountsIds)
        external
        view
        returns (uint128[] memory liquidatableAccountsIds)
    {
        for (uint256 i = 0; i < accountsIds.length; i++) {
            PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountsIds[i]);

            // if (perpsAccount.isLiquidatable(ud60x18(0), sd59x18(0))) {
            //     liquidatableAccountsIds[liquidatableAccountsIds.length] = accountsIds[i];
            // }
        }
    }

    // struct LiquidationContext {
    //     uint128 accountId;
    //     uint128 marketId;
    //     int128 sizeDelta;
    //     UD60x18 fillPrice;
    //     int256 fundingRate;
    //     int256 fundingFeePerUnit;
    //     SD59x18 totalFeesUsdX18;
    // }

    function liquidateAccounts(uint128[] calldata accountsIds) external onlyRegisteredLiquidator {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        UD60x18 liquidationFeeUsdX18 = globalConfiguration.liquidationFeeUsdX18;
        // TODO: apply this to _settle asap
        UD60x18 earnedFeesUsdX18 = liquidationFeeUsdX18.mul(ud60x18(accountsIds.length));

        for (uint256 i = 0; i < accountsIds.length; i++) {
            PerpsAccount.Data storage perpsAccount = PerpsAccount.load(accountsIds[i]);

            (, UD60x18 requiredMaintenanceMarginUsdX18, SD59x18 accountTotalUnrealizedPnlUsdX18) =
                perpsAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(0, sd59x18(0));
            SD59x18 marginBalanceUsdX18 = perpsAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18);

            if (
                PerpsAccount.isLiquidatable(
                    requiredMaintenanceMarginUsdX18, liquidationFeeUsdX18, marginBalanceUsdX18
                )
            ) {
                revert Errors.AccountNotLiquidatable(
                    accountsIds[i], requiredMaintenanceMarginUsdX18.intoUint256(), marginBalanceUsdX18.intoInt256()
                );
            }

            // TODO: Continue from here
            // (UD60x18 liquidatedCollateralUsdX18) = perpsAccount.liquidate();
            MarketOrder.load(accountsIds[i]).clear();
            // clear all possible custom orders (limit, tp/sl). Create account nonce to cancel all?
            // perpsAccount.clearCustomOrders();

            uint256 amountOfOpenPositions = perpsAccount.activeMarketsIds.length();

            for (uint256 j = 0; j < amountOfOpenPositions; j++) {
                uint128 marketId = perpsAccount.activeMarketsIds.at(j).toUint128();
                PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
                Position.Data storage position = Position.load(accountsIds[i], marketId);

                SD59x18 oldPositionSize = sd59x18(position.size);
                SD59x18 liquidationSize = unary(oldPositionSize);

                UD60x18 indexPriceX18 = perpMarket.getIndexPrice();
                UD60x18 markPriceX18 = perpMarket.getMarkPrice(liquidationSize, indexPriceX18);

                SD59x18 fundingRateUsdX18 = perpMarket.getCurrentFundingRate();
                SD59x18 fundingFeePerUnitUsdX18 = perpMarket.getNextFundingFeePerUnit(fundingRateUsdX18, markPriceX18);

                perpMarket.updateFunding(fundingRateUsdX18, fundingFeePerUnitUsdX18);

                position.clear();

                perpMarket.updateOpenInterest(liquidationSize, oldPositionSize, SD_ZERO);

                perpsAccount.updateActiveMarkets(marketId, oldPositionSize, SD_ZERO);
            }

            // must be an invariant
            assert(perpsAccount.activeMarketsIds.length() == 0);

            // TODO: pay execution gas costs to liquidator
            // pay earnedLiquidationFeesUsdX18 to liquidator
        }
    }
}
