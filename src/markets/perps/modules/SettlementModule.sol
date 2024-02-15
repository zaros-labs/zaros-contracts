// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { LimitedMintingERC20 } from "script/utils/LimitedMintingERC20.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { ISettlementStrategy } from "@zaros/markets/settlement/interfaces/ISettlementStrategy.sol";
import { ISettlementModule } from "../interfaces/ISettlementModule.sol";
import { MarketOrder } from "../storage/MarketOrder.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { GlobalConfiguration } from "../storage/GlobalConfiguration.sol";
import { PerpMarket } from "../storage/PerpMarket.sol";
import { Position } from "../storage/Position.sol";
import { SettlementConfiguration } from "../storage/SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { SafeERC20, IERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

contract SettlementModule is ISettlementModule {
    using EnumerableSet for EnumerableSet.UintSet;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using MarketOrder for MarketOrder.Data;
    using PerpsAccount for PerpsAccount.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeERC20 for IERC20;
    using SettlementConfiguration for SettlementConfiguration.Data;

    modifier onlyValidCustomOrderUpkeep(uint128 marketId, uint128 settlementId) {
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, settlementId);
        address settlementStrategy = settlementConfiguration.settlementStrategy;

        _requireIsSettlementStrategy(msg.sender, settlementStrategy);
        _;
    }

    modifier onlyMarketOrderUpkeep(uint128 marketId) {
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, SettlementConfiguration.MARKET_ORDER_SETTLEMENT_ID);
        address settlementStrategy = settlementConfiguration.settlementStrategy;

        _requireIsSettlementStrategy(msg.sender, settlementStrategy);
        _;
    }

    function settleMarketOrder(
        uint128 accountId,
        uint128 marketId,
        address settlementFeeReceiver,
        bytes calldata priceData
    )
        external
        onlyMarketOrderUpkeep(marketId)
    {
        MarketOrder.Data storage marketOrder = MarketOrder.loadExisting(accountId);

        SettlementPayload memory payload =
            SettlementPayload({ accountId: accountId, sizeDelta: marketOrder.sizeDelta });

        _settle(marketId, SettlementConfiguration.MARKET_ORDER_SETTLEMENT_ID, payload, priceData);

        marketOrder.clear();

        _paySettlementFees({
            settlementFeeReceiver: settlementFeeReceiver,
            marketId: marketId,
            settlementId: SettlementConfiguration.MARKET_ORDER_SETTLEMENT_ID,
            amountOfSettledTrades: 1
        });
    }

    function settleCustomOrders(
        uint128 marketId,
        uint128 settlementId,
        address settlementFeeReceiver,
        SettlementPayload[] calldata payloads,
        bytes calldata priceData,
        bytes calldata callbackData
    )
        external
        onlyValidCustomOrderUpkeep(marketId, settlementId)
    {
        // TODO: optimize this. We should be able to use the same market id and reports, and just loop on the
        // position's
        // validations and updates.
        for (uint256 i = 0; i < payloads.length; i++) {
            SettlementPayload memory payload = payloads[i];

            _settle(marketId, settlementId, payload, priceData);
        }

        _paySettlementFees({
            settlementFeeReceiver: settlementFeeReceiver,
            marketId: marketId,
            settlementId: settlementId,
            amountOfSettledTrades: payloads.length
        });

        ISettlementStrategy(msg.sender).afterSettlement(callbackData);
    }

    struct SettlementContext {
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
        Position.Data newPosition;
    }

    function _settle(
        uint128 marketId,
        uint128 settlementId,
        SettlementPayload memory payload,
        bytes memory priceData
    )
        internal
    {
        SettlementContext memory ctx;
        ctx.marketId = marketId;
        ctx.accountId = payload.accountId;
        ctx.sizeDelta = sd59x18(payload.sizeDelta);

        PerpMarket.Data storage perpMarket = PerpMarket.load(ctx.marketId);
        PerpsAccount.Data storage perpsAccount = PerpsAccount.loadExisting(ctx.accountId);
        Position.Data storage oldPosition = Position.load(ctx.accountId, ctx.marketId);
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

        if (ctx.newPosition.size == 0) {
            oldPosition.clear();
        } else {
            oldPosition.update(ctx.newPosition);
        }

        perpMarket.updateOpenInterest(ctx.sizeDelta, sd59x18(oldPosition.size), sd59x18(ctx.newPosition.size));

        perpsAccount.updateActiveMarkets(ctx.marketId, sd59x18(oldPosition.size), sd59x18(ctx.newPosition.size));

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

            // liquidityEngine.withdrawUsdToken(address(this), amountToIncrease);
            LimitedMintingERC20(ctx.usdToken).mint(address(this), amountToIncrease.intoUint256());
        }

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

    /// @dev We assume that the settlement fees are always properly deducted from the trading accounts, either from
    /// their margin or pnl.
    function _paySettlementFees(
        address settlementFeeReceiver,
        uint128 marketId,
        uint128 settlementId,
        uint256 amountOfSettledTrades
    )
        internal
    {
        address usdToken = GlobalConfiguration.load().usdToken;

        UD60x18 settlementFeePerTradeUsdX18 = ud60x18(SettlementConfiguration.load(marketId, settlementId).fee);
        UD60x18 totalSettlementFeeUsdX18 = settlementFeePerTradeUsdX18.mul(ud60x18(amountOfSettledTrades));

        LimitedMintingERC20(usdToken).mint(settlementFeeReceiver, totalSettlementFeeUsdX18.intoUint256());

        // TODO: add dynamic gas cost into settlementFee, checking settlementFeeGasCost stored and multiplying by
        // GasOracle.gasPrice()
        // liquidityEngine.withdrawUsdToken(keeper, ctx.settlementFeeUsdX18);
    }

    function _requireIsSettlementStrategy(address sender, address upkeep) internal pure {
        if (sender != upkeep && upkeep != address(0)) {
            revert Errors.OnlyUpkeep(sender, upkeep);
        }
    }
}
