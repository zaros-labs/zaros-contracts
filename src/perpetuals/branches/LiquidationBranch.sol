// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
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
import { UD60x18, ud60x18, ZERO as UD60x18_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD59x18_ZERO } from "@prb-math/SD59x18.sol";

contract LiquidationBranch {
    using EnumerableSet for EnumerableSet.UintSet;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using TradingAccount for TradingAccount.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;
    using MarketOrder for MarketOrder.Data;
    using SafeCast for uint256;

    event LogLiquidateAccount(
        address indexed keeper,
        uint128 indexed tradingAccountId,
        uint256 amountOfOpenPositions,
        uint256 requiredMaintenanceMarginUsd,
        int256 marginBalanceUsd,
        uint256 liquidatedCollateralUsd,
        uint128 liquidationFeeUsd
    );

    /// @param lowerBound The lower bound of the accounts to check
    /// @param upperBound The upper bound of the accounts to check
    function checkLiquidatableAccounts(
        uint256 lowerBound,
        uint256 upperBound
    )
        external
        view
        returns (uint128[] memory liquidatableAccountsIds)
    {
        liquidatableAccountsIds = new uint128[](upperBound - lowerBound);

        if (liquidatableAccountsIds.length == 0) return liquidatableAccountsIds;

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        uint256 cachedAccountsIdsWithActivePositionsLength =
            globalConfiguration.accountsIdsWithActivePositions.length();

        for (uint256 i = lowerBound; i < upperBound; i++) {
            if (i >= cachedAccountsIdsWithActivePositionsLength) break;
            uint128 tradingAccountId = uint128(globalConfiguration.accountsIdsWithActivePositions.at(i));
            TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);

            (, UD60x18 requiredMaintenanceMarginUsdX18, SD59x18 accountTotalUnrealizedPnlUsdX18) =
                tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(0, SD59x18_ZERO);
            SD59x18 marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18);

            if (TradingAccount.isLiquidatable(requiredMaintenanceMarginUsdX18, marginBalanceUsdX18)) {
                liquidatableAccountsIds[i] = tradingAccountId;
            }
        }
    }

    struct LiquidationContext {
        UD60x18 liquidationFeeUsdX18;
        uint128 tradingAccountId;
        UD60x18 requiredMaintenanceMarginUsdX18;
        SD59x18 marginBalanceUsdX18;
        UD60x18 liquidatedCollateralUsdX18;
        uint256[] activeMarketsIds;
        uint128 marketId;
        SD59x18 oldPositionSizeX18;
        SD59x18 liquidationSizeX18;
        UD60x18 markPriceX18;
        SD59x18 fundingRateX18;
        SD59x18 fundingFeePerUnitX18;
        UD60x18 newOpenInterestX18;
        SD59x18 newSkewX18;
    }

    /// @param accountsIds The list of accounts to liquidate
    /// @param liquidationFeeRecipient The address to receive the liquidation fee
    function liquidateAccounts(uint128[] calldata accountsIds, address liquidationFeeRecipient) external {
        if (accountsIds.length == 0) return;

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        if (!globalConfiguration.isLiquidatorEnabled[msg.sender]) {
            revert Errors.LiquidatorNotRegistered(msg.sender);
        }

        LiquidationContext memory ctx;

        ctx.liquidationFeeUsdX18 = ud60x18(globalConfiguration.liquidationFeeUsdX18);

        for (uint256 i; i < accountsIds.length; i++) {
            ctx.tradingAccountId = accountsIds[i];
            if (ctx.tradingAccountId == 0) continue;
            TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(ctx.tradingAccountId);

            (, UD60x18 requiredMaintenanceMarginUsdX18, SD59x18 accountTotalUnrealizedPnlUsdX18) =
                tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(0, SD59x18_ZERO);

            ctx.requiredMaintenanceMarginUsdX18 = requiredMaintenanceMarginUsdX18;
            ctx.marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18);

            if (!TradingAccount.isLiquidatable(requiredMaintenanceMarginUsdX18, ctx.marginBalanceUsdX18)) {
                continue;
            }

            ctx.liquidatedCollateralUsdX18 = tradingAccount.deductAccountMargin({
                feeRecipients: FeeRecipients.Data({
                    marginCollateralRecipient: globalConfiguration.marginCollateralRecipient,
                    orderFeeRecipient: address(0),
                    settlementFeeRecipient: liquidationFeeRecipient
                }),
                pnlUsdX18: requiredMaintenanceMarginUsdX18,
                orderFeeUsdX18: UD60x18_ZERO,
                settlementFeeUsdX18: ctx.liquidationFeeUsdX18
            });

            MarketOrder.load(ctx.tradingAccountId).clear();

            ctx.activeMarketsIds = tradingAccount.activeMarketsIds.values();

            for (uint256 j; j < ctx.activeMarketsIds.length; j++) {
                ctx.marketId = ctx.activeMarketsIds[j].toUint128();
                PerpMarket.Data storage perpMarket = PerpMarket.load(ctx.marketId);
                Position.Data storage position = Position.load(ctx.tradingAccountId, ctx.marketId);

                ctx.oldPositionSizeX18 = sd59x18(position.size);
                ctx.liquidationSizeX18 = -ctx.oldPositionSizeX18;

                ctx.markPriceX18 = perpMarket.getMarkPrice(ctx.liquidationSizeX18, perpMarket.getIndexPrice());

                ctx.fundingRateX18 = perpMarket.getCurrentFundingRate();
                ctx.fundingFeePerUnitX18 = perpMarket.getNextFundingFeePerUnit(ctx.fundingRateX18, ctx.markPriceX18);

                perpMarket.updateFunding(ctx.fundingRateX18, ctx.fundingFeePerUnitX18);
                position.clear();
                tradingAccount.updateActiveMarkets(ctx.marketId, ctx.oldPositionSizeX18, SD59x18_ZERO);

                perpMarket.updateOpenInterest(ctx.newOpenInterestX18, ctx.newSkewX18);
            }

            emit LogLiquidateAccount(
                msg.sender,
                ctx.tradingAccountId,
                ctx.activeMarketsIds.length,
                ctx.requiredMaintenanceMarginUsdX18.intoUint256(),
                ctx.marginBalanceUsdX18.intoInt256(),
                ctx.liquidatedCollateralUsdX18.intoUint256(),
                ctx.liquidationFeeUsdX18.intoUint128()
            );
        }
    }
}
