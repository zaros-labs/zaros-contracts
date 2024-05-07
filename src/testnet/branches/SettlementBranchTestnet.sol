// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { LimitedMintingERC20 } from "@zaros/testnet/LimitedMintingERC20.sol";
import { SettlementBranch } from "@zaros/perpetuals/branches/SettlementBranch.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";
import { TradingAccount } from "@zaros/perpetuals/leaves/TradingAccount.sol";
import { FeeRecipients } from "@zaros/perpetuals/leaves/FeeRecipients.sol";
import { GlobalConfiguration } from "@zaros/perpetuals/leaves/GlobalConfiguration.sol";
import { PerpMarket } from "@zaros/perpetuals/leaves/PerpMarket.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { Points } from "../leaves/Points.sol";

// Open Zeppelin dependencies
import { SafeERC20, IERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

contract SettlementBranchTestnet is SettlementBranch {
    using EnumerableSet for EnumerableSet.UintSet;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using MarketOrder for MarketOrder.Data;
    using TradingAccount for TradingAccount.Data;
    using PerpMarket for PerpMarket.Data;
    using Points for Points.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeERC20 for IERC20;
    using SettlementConfiguration for SettlementConfiguration.Data;

    struct FillOrderContextTestnet {
        address usdToken;
        uint128 marketId;
        uint128 tradingAccountId;
        SD59x18 orderFeeUsdX18;
        UD60x18 settlementFeeUsdX18;
        SD59x18 sizeDelta;
        UD60x18 fillPrice;
        SD59x18 pnl;
        SD59x18 fundingFeePerUnit;
        SD59x18 fundingRate;
        UD60x18 newOpenInterest;
        SD59x18 newSkew;
        Points.Data userPoints;
        Position.Data newPosition;
    }

    function _fillOrder(
        uint128 tradingAccountId,
        uint128 marketId,
        uint128 settlementConfigurationId,
        int128 sizeDelta,
        FeeRecipients.Data memory feeRecipients,
        bytes memory priceData
    )
        internal
        virtual
        override
    {
        // FillOrderContextTestnet memory ctx;
        // ctx.marketId = marketId;
        // ctx.tradingAccountId = tradingAccountId;
        // ctx.sizeDelta = sd59x18(sizeDelta);

        // PerpMarket.Data storage perpMarket = PerpMarket.load(ctx.marketId);
        // TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(ctx.tradingAccountId);
        // SettlementConfiguration.Data storage settlementConfiguration =
        //     SettlementConfiguration.load(marketId, settlementConfigurationId);
        // GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        // Position.Data storage oldPosition = Position.load(ctx.tradingAccountId, ctx.marketId);

        // ctx.usdToken = globalConfiguration.usdToken;

        // // TODO: Handle state validation without losing the gas fee potentially paid by CL automation.
        // // TODO: potentially update all checks to return true / false and bubble up the revert to the caller?
        // globalConfiguration.checkMarketIsEnabled(ctx.marketId);
        // perpMarket.checkTradeSize(ctx.sizeDelta);

        // bytes memory verifiedPriceData = settlementConfiguration.verifyPriceData(priceData);
        // ctx.fillPrice = perpMarket.getMarkPrice(
        //     ctx.sizeDelta, settlementConfiguration.getOffchainPrice(verifiedPriceData, ctx.sizeDelta.gt(SD_ZERO))
        // );

        // ctx.fundingRate = perpMarket.getCurrentFundingRate();
        // ctx.fundingFeePerUnit = perpMarket.getNextFundingFeePerUnit(ctx.fundingRate, ctx.fillPrice);

        // perpMarket.updateFunding(ctx.fundingRate, ctx.fundingFeePerUnit);

        // ctx.orderFeeUsdX18 = perpMarket.getOrderFeeUsd(ctx.sizeDelta, ctx.fillPrice);
        // // TODO: add dynamic gas cost in the end
        // ctx.settlementFeeUsdX18 = ud60x18(uint256(settlementConfiguration.fee));

        // {
        //     (
        //         UD60x18 requiredInitialMarginUsdX18,
        //         UD60x18 requiredMaintenanceMarginUsdX18,
        //         SD59x18 accountTotalUnrealizedPnlUsdX18
        //     ) = tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(marketId, ctx.sizeDelta);

        //     tradingAccount.validateMarginRequirement(
        //         requiredInitialMarginUsdX18.add(requiredMaintenanceMarginUsdX18),
        //         tradingAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18),
        //         ctx.orderFeeUsdX18.add(ctx.settlementFeeUsdX18.intoSD59x18())
        //     );
        // }

        // ctx.pnl = oldPosition.getUnrealizedPnl(ctx.fillPrice).add(
        //     oldPosition.getAccruedFunding(ctx.fundingFeePerUnit)
        // ).add(ctx.orderFeeUsdX18).add(ctx.settlementFeeUsdX18.intoSD59x18());

        // ctx.newPosition = Position.Data({
        //     size: sd59x18(oldPosition.size).add(ctx.sizeDelta).intoInt256(),
        //     lastInteractionPrice: ctx.fillPrice.intoUint128(),
        //     lastInteractionFundingFeePerUnit: ctx.fundingFeePerUnit.intoInt256().toInt128()
        // });

        // (ctx.newOpenInterest, ctx.newSkew) = perpMarket.checkOpenInterestLimits(
        //     ctx.sizeDelta, sd59x18(oldPosition.size), sd59x18(ctx.newPosition.size)
        // );
        // perpMarket.updateOpenInterest(ctx.newOpenInterest, ctx.newSkew);
        // tradingAccount.updateActiveMarkets(ctx.marketId, sd59x18(oldPosition.size), sd59x18(ctx.newPosition.size));

        // if (ctx.newPosition.size == 0) {
        //     oldPosition.clear();
        // } else {
        //     oldPosition.update(ctx.newPosition);
        // }

        // // TODO: Handle negative margin case
        // if (ctx.pnl.lt(SD_ZERO)) {
        //     UD60x18 amountToDeduct = ctx.pnl.intoUD60x18();
        //     // TODO: update to liquidation pool and fee pool addresses
        //     tradingAccount.deductAccountMargin(
        //         msg.sender,
        //         msg.sender,
        //         amountToDeduct,
        //         ctx.orderFeeUsdX18.gt(SD_ZERO) ? ctx.orderFeeUsdX18.intoUD60x18() : UD_ZERO
        //     );
        // } else if (ctx.pnl.gt(SD_ZERO)) {
        //     UD60x18 amountToIncrease = ctx.pnl.intoUD60x18();
        //     tradingAccount.deposit(ctx.usdToken, amountToIncrease);
        //     Points.updatePnlPoints(tradingAccount.owner, ctx.pnl);

        //     // liquidityEngine.withdrawUsdToken(address(this), amountToIncrease);
        //     // NOTE: testnet only
        //     LimitedMintingERC20(ctx.usdToken).mint(address(this), amountToIncrease.intoUint256());
        // }

        // Points.updateTradingVolumePoints(tradingAccount.owner,
        // ctx.sizeDelta.abs().intoUD60x18().mul(ctx.fillPrice));

        // emit LogSettleOrder(
        //     msg.sender,
        //     ctx.tradingAccountId,
        //     ctx.marketId,
        //     ctx.sizeDelta.intoInt256(),
        //     ctx.fillPrice.intoUint256(),
        //     ctx.orderFeeUsdX18.intoInt256(),
        //     ctx.settlementFeeUsdX18.intoUint256(),
        //     ctx.pnl.intoInt256(),
        //     ctx.newPosition
        // );
    }
}
