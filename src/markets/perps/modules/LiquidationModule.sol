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

    struct LiquidationContext {
        UD60x18 liquidationFeeUsdX18;
        UD60x18 earnedLiquidationFeeUsdX18;
        uint128 accountId;
        SD59x18 marginBalanceUsdX18;
        UD60x18 liquidatedCollateralUsdX18;
        uint256 amountOfOpenPositions;
        uint128 marketId;
        SD59x18 oldPositionSizeX18;
        SD59x18 liquidationSizeX18;
        UD60x18 markPriceX18;
        SD59x18 fundingRateUsdX18;
        SD59x18 fundingFeePerUnitUsdX18;
    }

    function liquidateAccounts(uint128[] calldata accountsIds) external onlyRegisteredLiquidator {
        if (accountsIds.length == 0) return;

        LiquidationContext memory ctx;

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        ctx.liquidationFeeUsdX18 = ud60x18(globalConfiguration.liquidationFeeUsdX18);
        // TODO: apply this to _settle asap
        ctx.earnedLiquidationFeeUsdX18 = ctx.liquidationFeeUsdX18.mul(ud60x18(accountsIds.length));

        for (uint256 i = 0; i < accountsIds.length; i++) {
            ctx.accountId = accountsIds[i];
            PerpsAccount.Data storage perpsAccount = PerpsAccount.load(ctx.accountId);

            (, UD60x18 requiredMaintenanceMarginUsdX18, SD59x18 accountTotalUnrealizedPnlUsdX18) =
                perpsAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(0, sd59x18(0));
            ctx.marginBalanceUsdX18 = perpsAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18);

            if (
                !PerpsAccount.isLiquidatable(
                    requiredMaintenanceMarginUsdX18, ctx.liquidationFeeUsdX18, ctx.marginBalanceUsdX18
                )
            ) {
                revert Errors.AccountNotLiquidatable(
                    ctx.accountId, requiredMaintenanceMarginUsdX18.intoUint256(), ctx.marginBalanceUsdX18.intoInt256()
                );
            }

            // TODO: Continue from here
            ctx.liquidatedCollateralUsdX18 = perpsAccount.liquidate();
            MarketOrder.load(ctx.accountId).clear();
            // clear all possible custom orders (limit, tp/sl). Create account nonce to cancel all?
            // perpsAccount.clearCustomOrders();

            ctx.amountOfOpenPositions = perpsAccount.activeMarketsIds.length();

            for (uint256 j = 0; j < ctx.amountOfOpenPositions; j++) {
                ctx.marketId = perpsAccount.activeMarketsIds.at(j).toUint128();
                PerpMarket.Data storage perpMarket = PerpMarket.load(ctx.marketId);
                Position.Data storage position = Position.load(ctx.accountId, ctx.marketId);

                ctx.oldPositionSizeX18 = sd59x18(position.size);
                ctx.liquidationSizeX18 = unary(ctx.oldPositionSizeX18);

                ctx.markPriceX18 = perpMarket.getMarkPrice(ctx.liquidationSizeX18, perpMarket.getIndexPrice());

                ctx.fundingRateUsdX18 = perpMarket.getCurrentFundingRate();
                ctx.fundingFeePerUnitUsdX18 =
                    perpMarket.getNextFundingFeePerUnit(ctx.fundingRateUsdX18, ctx.markPriceX18);

                perpMarket.updateFunding(ctx.fundingRateUsdX18, ctx.fundingFeePerUnitUsdX18);

                position.clear();

                perpMarket.updateOpenInterest(ctx.liquidationSizeX18, ctx.oldPositionSizeX18, SD_ZERO);

                perpsAccount.updateActiveMarkets(ctx.marketId, ctx.oldPositionSizeX18, SD_ZERO);
            }

            // must be an invariant
            assert(perpsAccount.activeMarketsIds.length() == 0);

            // TODO: pay execution gas costs to liquidator
            // pay earnedLiquidationFeesUsdX18 to liquidator
            // liquidityEngine.withdrawUsdToken(liquidatedCollateralUsdX18, msg.sender);
        }
    }
}
