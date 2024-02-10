// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { BasicReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { ISettlementModule } from "../interfaces/ISettlementModule.sol";
import { MarketOrder } from "../storage/MarketOrder.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { GlobalConfiguration } from "../storage/GlobalConfiguration.sol";
import { PerpMarket } from "../storage/PerpMarket.sol";
import { Position } from "../storage/Position.sol";
import { SettlementConfiguration } from "../storage/SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

contract SettlementModule is ISettlementModule {
    using EnumerableSet for EnumerableSet.UintSet;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using MarketOrder for MarketOrder.Data;
    using PerpsAccount for PerpsAccount.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SettlementConfiguration for SettlementConfiguration.Data;

    modifier onlyValidCustomTriggerUpkeep() {
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
        bytes calldata extraData
    )
        external
        onlyMarketOrderUpkeep(marketId)
    {
        MarketOrder.Data storage marketOrder = MarketOrder.load(accountId);

        SettlementPayload memory payload =
            SettlementPayload({ accountId: accountId, sizeDelta: marketOrder.sizeDelta });
        _settle(marketId, SettlementConfiguration.MARKET_ORDER_SETTLEMENT_ID, payload, extraData);

        marketOrder.clear();
    }

    function settleCustomTriggers(
        uint128 marketId,
        uint128 settlementId,
        SettlementPayload[] calldata payloads,
        bytes calldata extraData
    )
        external
        onlyValidCustomTriggerUpkeep
    {
        // TODO: optimize this. We should be able to use the same market id and reports, and just loop on the
        // position's
        // validations and updates.
        for (uint256 i = 0; i < payloads.length; i++) {
            SettlementPayload memory payload = payloads[i];

            _settle(marketId, settlementId, payload, extraData);
        }
    }

    struct SettlementContext {
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
        bytes memory extraData
    )
        internal
    {
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

        globalConfiguration.checkMarketIsEnabled(ctx.marketId);
        // TODO: Handle state validation without losing the gas fee potentially paid by CL automation.
        // TODO: potentially update all checks to return true / false and bubble up the revert to the caller?

        bytes memory verifiedExtraData = settlementConfiguration.verifyExtraData(extraData);

        ctx.fillPrice = perpMarket.getMarkPrice(
            ctx.sizeDelta, settlementConfiguration.getSettlementPrice(verifiedExtraData, ctx.sizeDelta.gt(SD_ZERO))
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

        ctx.pnl =
            oldPosition.getUnrealizedPnl(ctx.fillPrice).add(oldPosition.getAccruedFunding(ctx.fundingFeePerUnit));

        // TODO: Handle negative margin case
        if (ctx.pnl.lt(SD_ZERO)) {
            UD60x18 amountToDeduct = ctx.pnl.intoUD60x18();
            perpsAccount.deductAccountMargin(amountToDeduct);
        } else if (ctx.pnl.gt(SD_ZERO)) {
            UD60x18 amountToIncrease = ctx.pnl.intoUD60x18();
            perpsAccount.deposit(usdToken, amountToIncrease);

            // liquidityEngine.withdrawUsdToken(address(this), amountToIncrease);
        }

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

        // TODO: add dynamic gas cost into settlementFee
        // liquidityEngine.withdrawUsdToken(keeper, ctx.settlementFeeUsdX18);

        // TODO: Enrich this event
        emit LogSettleOrder(msg.sender, ctx.accountId, ctx.marketId, ctx.pnl.intoInt256(), ctx.newPosition);
    }

    function _requireIsSettlementStrategy(address sender, address upkeep) internal pure {
        if (sender != upkeep && upkeep != address(0)) {
            revert Errors.OnlyUpkeep(sender, upkeep);
        }
    }
}
