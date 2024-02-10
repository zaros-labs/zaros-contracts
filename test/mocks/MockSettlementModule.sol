// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import "@zaros/markets/perps/modules/SettlementModule.sol";

contract MockSettlementModule is SettlementModule {
    using GlobalConfiguration for GlobalConfiguration.Data;
    using PerpsAccount for PerpsAccount.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;
    using SettlementConfiguration for SettlementConfiguration.Data;
    using SafeCast for uint256;
    using SafeCast for int256;

    function mockSettle(uint128 marketId, uint128 settlementId, SettlementPayload calldata payload) external {
        _mockSettle(marketId, settlementId, payload);
    }

    function _mockSettle(uint128 marketId, uint128 settlementId, SettlementPayload memory payload) internal {
        SettlementContext memory ctx;
        ctx.marketId = marketId;
        ctx.accountId = payload.accountId;
        ctx.sizeDelta = sd59x18(payload.sizeDelta);

        PerpMarket.Data storage perpMarket = PerpMarket.load(ctx.marketId);
        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(ctx.accountId);
        Position.Data storage oldPosition = Position.load(ctx.accountId, ctx.marketId);
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, settlementId);
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        address usdToken = globalConfiguration.usdToken;

        // globalConfiguration.checkMarketIsEnabled(ctx.marketId);
        // TODO: Handle state validation without losing the gas fee potentially paid by CL automation.
        // TODO: potentially update all checks to return true / false and bubble up the revert to the caller?

        ctx.fillPrice = perpMarket.getMarkPrice(ctx.sizeDelta, perpMarket.getIndexPrice());

        ctx.fundingRate = perpMarket.getCurrentFundingRate();
        ctx.fundingFeePerUnit = perpMarket.getNextFundingFeePerUnit(ctx.fundingRate, ctx.fillPrice);

        perpMarket.updateFunding(ctx.fundingRate, ctx.fundingFeePerUnit);

        ctx.totalFeesUsdX18 = perpMarket.getOrderFeeUsd(ctx.sizeDelta, ctx.fillPrice).add(
            ud60x18(uint256(settlementConfiguration.fee)).intoSD59x18()
        );

        {
            (
                UD60x18 requiredInitialMarginUsdX18,
                UD60x18 requiredMaintenanceMarginUsdX18,
                SD59x18 accountTotalUnrealizedPnlUsdX18
            ) = perpsAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(marketId, ctx.sizeDelta);

            perpsAccount.validateMarginRequirement(
                requiredInitialMarginUsdX18.add(requiredMaintenanceMarginUsdX18),
                perpsAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18),
                ctx.totalFeesUsdX18
            );
        }

        ctx.pnl = oldPosition.getUnrealizedPnl(ctx.fillPrice).add(
            sd59x18(uint256(settlementConfiguration.fee).toInt256())
        ).add(ctx.totalFeesUsdX18).add(oldPosition.getAccruedFunding(ctx.fundingFeePerUnit));

        // TODO: Handle negative margin case
        if (ctx.pnl.lt(SD_ZERO)) {
            UD60x18 amountToDeduct = ctx.pnl.intoUD60x18();
            perpsAccount.deductAccountMargin(amountToDeduct);
        } else if (ctx.pnl.gt(SD_ZERO)) {
            UD60x18 amountToIncrease = ctx.pnl.intoUD60x18();
            perpsAccount.deposit(usdToken, amountToIncrease);
        }

        ctx.newPosition = Position.Data({
            size: sd59x18(oldPosition.size).add(ctx.sizeDelta).intoInt256(),
            lastInteractionPrice: ctx.fillPrice.intoUint128(),
            lastInteractionFundingFeePerUnit: ctx.fundingFeePerUnit.intoInt256().toInt128()
        });

        // TODO: liquidityEngine.withdrawUsdToken(upkeep, ctx.marketId, ctx.fee);
        perpMarket.updateOpenInterest(ctx.sizeDelta, sd59x18(oldPosition.size), sd59x18(ctx.newPosition.size));

        perpsAccount.updateActiveMarkets(ctx.marketId, sd59x18(oldPosition.size), sd59x18(ctx.newPosition.size));
        if (ctx.newPosition.size == 0) {
            oldPosition.clear();
        } else {
            oldPosition.update(ctx.newPosition);
        }

        emit LogSettleOrder(msg.sender, ctx.accountId, ctx.marketId, ctx.pnl.intoInt256(), ctx.newPosition);
    }
}
