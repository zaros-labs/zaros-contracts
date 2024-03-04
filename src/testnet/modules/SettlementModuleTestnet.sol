// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { LimitedMintingERC20 } from "@zaros/testnet/LimitedMintingERC20.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { ISettlementStrategy } from "@zaros/markets/settlement/interfaces/ISettlementStrategy.sol";
import { OcoOrderSettlementStrategy } from "@zaros/markets/settlement/OcoOrderSettlementStrategy.sol";
import { OcoOrder } from "@zaros/markets/settlement/storage/OcoOrder.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementModule } from "@zaros/markets/perps/modules/SettlementModule.sol";
import { MarketOrder } from "@zaros/markets/perps/storage/MarketOrder.sol";
import { PerpsAccount } from "@zaros/markets/perps/storage/PerpsAccount.sol";
import { GlobalConfiguration } from "@zaros/markets/perps/storage/GlobalConfiguration.sol";
import { PerpMarket } from "@zaros/markets/perps/storage/PerpMarket.sol";
import { Position } from "@zaros/markets/perps/storage/Position.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { Points } from "../storage/Points.sol";
import { PointsConfig } from "../storage/PointsConfig.sol";

// Open Zeppelin dependencies
import { SafeERC20, IERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

contract SettlementModuleTestnet is SettlementModule {
    using EnumerableSet for EnumerableSet.UintSet;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using MarketOrder for MarketOrder.Data;
    using PerpsAccount for PerpsAccount.Data;
    using PerpMarket for PerpMarket.Data;
    using Points for Points.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeERC20 for IERC20;
    using SettlementConfiguration for SettlementConfiguration.Data;

    struct SettlementContextTestnet {
        address usdToken;
        uint128 marketId;
        uint128 accountId;
        SD59x18 orderFeeUsdX18;
        UD60x18 settlementFeeUsdX18;
        SD59x18 sizeDelta;
        UD60x18 fillPrice;
        SD59x18 pnl;
        SD59x18 fundingFeePerUnit;
        SD59x18 fundingRate;
        Points.Data userPoints;
        Position.Data newPosition;
    }

    function _settle(
        uint128 marketId,
        uint128 settlementId,
        SettlementPayload memory payload,
        bytes memory priceData
    )
        internal
        virtual
        override
    {
        SettlementContextTestnet memory ctx;
        ctx.marketId = marketId;
        ctx.accountId = payload.accountId;
        Position.Data storage oldPosition = Position.load(ctx.accountId, ctx.marketId);
        // TODO: Remove this type(int128) logic after testnet
        ctx.sizeDelta = (payload.sizeDelta == type(int128).min || payload.sizeDelta == type(int128).max)
            ? unary(sd59x18(oldPosition.size))
            : sd59x18(payload.sizeDelta);

        PerpMarket.Data storage perpMarket = PerpMarket.load(ctx.marketId);
        PerpsAccount.Data storage perpsAccount = PerpsAccount.loadExisting(ctx.accountId);
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, settlementId);
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        ctx.usdToken = globalConfiguration.usdToken;

        globalConfiguration.checkMarketIsEnabled(ctx.marketId);
        // TODO: Handle state validation without losing the gas fee potentially paid by CL automation.
        // TODO: potentially update all checks to return true / false and bubble up the revert to the caller?

        bytes memory verifiedPriceData = settlementConfiguration.verifyPriceData(priceData);
        ctx.fillPrice = perpMarket.getMarkPrice(
            ctx.sizeDelta, settlementConfiguration.getSettlementPrice(verifiedPriceData, ctx.sizeDelta.gt(SD_ZERO))
        );

        globalConfiguration.checkTradeSizeUsd(ctx.sizeDelta, ctx.fillPrice);

        ctx.fundingRate = perpMarket.getCurrentFundingRate();
        ctx.fundingFeePerUnit = perpMarket.getNextFundingFeePerUnit(ctx.fundingRate, ctx.fillPrice);

        perpMarket.updateFunding(ctx.fundingRate, ctx.fundingFeePerUnit);

        ctx.orderFeeUsdX18 = perpMarket.getOrderFeeUsd(ctx.sizeDelta, ctx.fillPrice);
        // TODO: add dynamic gas cost in the end
        ctx.settlementFeeUsdX18 = ud60x18(uint256(settlementConfiguration.fee));

        {
            (
                UD60x18 requiredInitialMarginUsdX18,
                UD60x18 requiredMaintenanceMarginUsdX18,
                SD59x18 accountTotalUnrealizedPnlUsdX18
            ) = perpsAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(marketId, ctx.sizeDelta);

            perpsAccount.validateMarginRequirement(
                requiredInitialMarginUsdX18.add(requiredMaintenanceMarginUsdX18),
                perpsAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18),
                ctx.orderFeeUsdX18.add(ctx.settlementFeeUsdX18.intoSD59x18())
            );
        }

        ctx.pnl = oldPosition.getUnrealizedPnl(ctx.fillPrice).add(
            oldPosition.getAccruedFunding(ctx.fundingFeePerUnit)
        ).add(ctx.orderFeeUsdX18).add(ctx.settlementFeeUsdX18.intoSD59x18());

        ctx.newPosition = Position.Data({
            size: sd59x18(oldPosition.size).add(ctx.sizeDelta).intoInt256(),
            lastInteractionPrice: ctx.fillPrice.intoUint128(),
            lastInteractionFundingFeePerUnit: ctx.fundingFeePerUnit.intoInt256().toInt128()
        });

        perpMarket.updateOpenInterest(ctx.sizeDelta, sd59x18(oldPosition.size), sd59x18(ctx.newPosition.size));
        perpsAccount.updateActiveMarkets(ctx.marketId, sd59x18(oldPosition.size), sd59x18(ctx.newPosition.size));

        if (ctx.newPosition.size == 0) {
            oldPosition.clear();
        } else {
            oldPosition.update(ctx.newPosition);
        }

        // TODO: Handle negative margin case
        if (ctx.pnl.lt(SD_ZERO)) {
            UD60x18 amountToDeduct = ctx.pnl.intoUD60x18();
            // TODO: update to liquidation pool and fee pool addresses
            perpsAccount.deductAccountMargin(
                msg.sender,
                msg.sender,
                amountToDeduct,
                ctx.orderFeeUsdX18.gt(SD_ZERO) ? ctx.orderFeeUsdX18.intoUD60x18() : UD_ZERO
            );
        } else if (ctx.pnl.gt(SD_ZERO)) {
            UD60x18 amountToIncrease = ctx.pnl.intoUD60x18();
            perpsAccount.deposit(ctx.usdToken, amountToIncrease);
            Points.load(perpsAccount.owner).updatePnlPoints(ctx.pnl);

            // liquidityEngine.withdrawUsdToken(address(this), amountToIncrease);
            // NOTE: testnet only
            LimitedMintingERC20(ctx.usdToken).mint(address(this), amountToIncrease.intoUint256());
        }

        Points.load(perpsAccount.owner).updateTradingVolumePoints(
            ctx.sizeDelta.abs().intoUD60x18().mul(ctx.fillPrice)
        );

        emit LogSettleOrder(
            msg.sender,
            ctx.accountId,
            ctx.marketId,
            ctx.sizeDelta.intoInt256(),
            ctx.fillPrice.intoUint256(),
            ctx.orderFeeUsdX18.intoInt256(),
            ctx.settlementFeeUsdX18.intoUint256(),
            ctx.pnl.intoInt256(),
            ctx.newPosition
        );
    }

    function _calculatePnlPoints(SD59x18 pnl) internal pure returns (UD60x18) {
        return pnl.intoUD60x18().div(ud60x18(10_000e18)).sub(pnl.intoUD60x18().mod(ud60x18(10_000e18))).mul(
            ud60x18(PointsConfig.POINTS_PER_10K_PNL)
        );
    }

    function _calculateTradeSizePoints(SD59x18 sizeDelta, UD60x18 fillPrice) internal pure returns (UD60x18) {
        return sizeDelta.abs().intoUD60x18().mul(fillPrice).div(ud60x18(10_000e18)).sub(
            sizeDelta.abs().intoUD60x18().mul(fillPrice).mod(ud60x18(10_000e18))
        ).mul(ud60x18(PointsConfig.POINTS_PER_10K_TRADE_SIZE));
    }
}
