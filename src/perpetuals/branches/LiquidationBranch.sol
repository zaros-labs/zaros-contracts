// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { ILiquidationBranch } from "../interfaces/ILiquidationBranch.sol";
import { FeeRecipients } from "../leaves/FeeRecipients.sol";
import { GlobalConfiguration } from "../leaves/GlobalConfiguration.sol";
import { TradingAccount } from "../leaves/TradingAccount.sol";
import { PerpMarket } from "../leaves/PerpMarket.sol";
import { Position } from "../leaves/Position.sol";
import { MarketOrder } from "../leaves/MarketOrder.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

contract LiquidationBranch is ILiquidationBranch {
    using EnumerableSet for EnumerableSet.UintSet;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using TradingAccount for TradingAccount.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;
    using MarketOrder for MarketOrder.Data;
    using SafeCast for uint256;

    modifier onlyRegisteredLiquidator() {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        if (!globalConfiguration.isLiquidatorEnabled[msg.sender]) {
            revert Errors.LiquidatorNotRegistered(msg.sender);
        }

        _;
    }

    function checkLiquidatableAccounts(
        uint256 lowerBound,
        uint256 upperBound
    )
        external
        view
        returns (uint128[] memory liquidatableAccountsIds)
    {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        UD60x18 liquidationFeeUsdX18 = ud60x18(globalConfiguration.liquidationFeeUsdX18);

        for (uint256 i = lowerBound; i < upperBound; i++) {
            uint128 tradingAccountId = uint128(globalConfiguration.accountsIdsWithActivePositions.at(i));
            TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);

            (, UD60x18 requiredMaintenanceMarginUsdX18, SD59x18 accountTotalUnrealizedPnlUsdX18) =
                tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(0, sd59x18(0));
            SD59x18 marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18);

            if (
                TradingAccount.isLiquidatable(
                    requiredMaintenanceMarginUsdX18, liquidationFeeUsdX18, marginBalanceUsdX18
                )
            ) {
                liquidatableAccountsIds[liquidatableAccountsIds.length] = tradingAccountId;
            }
        }
    }

    struct LiquidationContext {
        UD60x18 liquidationFeeUsdX18;
        uint128 tradingAccountId;
        UD60x18 requiredMaintenanceMarginUsdX18;
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

    function liquidateAccounts(
        uint128[] calldata accountsIds,
        address feeRecipient
    )
        external
        onlyRegisteredLiquidator
    {
        if (accountsIds.length == 0) return;

        LiquidationContext memory ctx;

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        ctx.liquidationFeeUsdX18 = ud60x18(globalConfiguration.liquidationFeeUsdX18);

        for (uint256 i = 0; i < accountsIds.length; i++) {
            ctx.tradingAccountId = accountsIds[i];
            TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(ctx.tradingAccountId);

            (, UD60x18 requiredMaintenanceMarginUsdX18, SD59x18 accountTotalUnrealizedPnlUsdX18) =
                tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(0, sd59x18(0));

            ctx.requiredMaintenanceMarginUsdX18 = requiredMaintenanceMarginUsdX18;
            ctx.marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18);

            if (
                !TradingAccount.isLiquidatable(
                    requiredMaintenanceMarginUsdX18, ctx.liquidationFeeUsdX18, ctx.marginBalanceUsdX18
                )
            ) {
                revert Errors.AccountNotLiquidatable(
                    ctx.tradingAccountId,
                    requiredMaintenanceMarginUsdX18.intoUint256(),
                    ctx.marginBalanceUsdX18.intoInt256()
                );
            }

            // TODO: Update margin recipient
            UD60x18 liquidatedCollateralUsdX18 = tradingAccount.deductAccountMargin({
                feeRecipients: FeeRecipients.Data({
                    marginCollateralRecipient: feeRecipient,
                    orderFeeRecipient: address(0),
                    settlementFeeRecipient: feeRecipient
                }),
                pnlUsdX18: ctx.marginBalanceUsdX18.gt(requiredMaintenanceMarginUsdX18.intoSD59x18())
                    ? ctx.marginBalanceUsdX18.intoUD60x18()
                    : requiredMaintenanceMarginUsdX18,
                orderFeeUsdX18: UD_ZERO,
                settlementFeeUsdX18: ctx.liquidationFeeUsdX18
            });
            ctx.liquidatedCollateralUsdX18 = liquidatedCollateralUsdX18;
            MarketOrder.load(ctx.tradingAccountId).clear();

            ctx.amountOfOpenPositions = tradingAccount.activeMarketsIds.length();

            for (uint256 j = 0; j < ctx.amountOfOpenPositions; j++) {
                ctx.marketId = tradingAccount.activeMarketsIds.at(j).toUint128();
                PerpMarket.Data storage perpMarket = PerpMarket.load(ctx.marketId);
                Position.Data storage position = Position.load(ctx.tradingAccountId, ctx.marketId);

                ctx.oldPositionSizeX18 = sd59x18(position.size);
                ctx.liquidationSizeX18 = unary(ctx.oldPositionSizeX18);

                ctx.markPriceX18 = perpMarket.getMarkPrice(ctx.liquidationSizeX18, perpMarket.getIndexPrice());

                ctx.fundingRateUsdX18 = perpMarket.getCurrentFundingRate();
                ctx.fundingFeePerUnitUsdX18 =
                    perpMarket.getNextFundingFeePerUnit(ctx.fundingRateUsdX18, ctx.markPriceX18);

                perpMarket.updateFunding(ctx.fundingRateUsdX18, ctx.fundingFeePerUnitUsdX18);

                position.clear();

                (UD60x18 newOpenInterest, SD59x18 newSkew) =
                    perpMarket.checkOpenInterestLimits(ctx.liquidationSizeX18, ctx.oldPositionSizeX18, SD_ZERO);
                perpMarket.updateOpenInterest(newOpenInterest, newSkew);

                tradingAccount.updateActiveMarkets(ctx.marketId, ctx.oldPositionSizeX18, SD_ZERO);
            }

            // asserts invariant
            assert(tradingAccount.activeMarketsIds.length() == 0);

            emit LogLiquidateAccount(
                msg.sender,
                ctx.tradingAccountId,
                feeRecipient,
                ctx.amountOfOpenPositions,
                ctx.requiredMaintenanceMarginUsdX18.intoUint256(),
                ctx.marginBalanceUsdX18.intoInt256(),
                ctx.liquidatedCollateralUsdX18.intoUint256(),
                ctx.liquidationFeeUsdX18.intoUint128()
            );
        }
    }
}
