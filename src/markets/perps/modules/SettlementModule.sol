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
        MarketOrder.Data storage marketOrder = MarketOrder.load(accountId, marketId);

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

    struct SettleVars {
        uint128 marketId;
        uint128 accountId;
        SD59x18 totalFeesUsdX18;
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
        SettleVars memory vars;
        vars.marketId = marketId;
        vars.accountId = payload.accountId;
        vars.sizeDelta = sd59x18(payload.sizeDelta);

        PerpMarket.Data storage perpMarket = PerpMarket.load(vars.marketId);
        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(vars.accountId);
        Position.Data storage oldPosition = Position.load(vars.accountId, vars.marketId);
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, settlementId);
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        address usdToken = globalConfiguration.usdToken;

        globalConfiguration.checkMarketIsEnabled(vars.marketId);
        // TODO: Handle state validation without losing the gas fee potentially paid by CL automation.
        // TODO: potentially update all checks to return true / false and bubble up the revert to the caller?
        // perpsAccount.checkIsNotLiquidatable();
        perpMarket.validateNewOpenInterest(vars.sizeDelta);

        bytes memory verifiedExtraData = settlementConfiguration.verifyExtraData(extraData);

        vars.fillPrice = perpMarket.getMarkPrice(
            vars.sizeDelta, settlementConfiguration.getSettlementPrice(verifiedExtraData, vars.sizeDelta.gt(SD_ZERO))
        );

        vars.fundingRate = perpMarket.getCurrentFundingRate();
        vars.fundingFeePerUnit = perpMarket.getNextFundingFeePerUnit(vars.fundingRate, vars.fillPrice);

        perpMarket.updateFunding(vars.fundingRate, vars.fundingFeePerUnit);

        vars.totalFeesUsdX18 = perpMarket.getOrderFeeUsd(vars.sizeDelta, vars.fillPrice).add(
            ud60x18(uint256(settlementConfiguration.fee)).intoSD59x18()
        );

        {
            (
                UD60x18 requiredInitialMarginUsdX18,
                UD60x18 requiredMaintenanceMarginUsdX18,
                SD59x18 accountTotalUnrealizedPnlUsdX18
            ) = perpsAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(marketId, vars.sizeDelta);

            perpsAccount.validateMarginRequirement(
                requiredInitialMarginUsdX18.add(requiredMaintenanceMarginUsdX18),
                perpsAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18),
                vars.totalFeesUsdX18
            );
        }

        vars.pnl = oldPosition.getUnrealizedPnl(vars.fillPrice).add(
            sd59x18(uint256(settlementConfiguration.fee).toInt256())
        ).add(vars.totalFeesUsdX18).add(oldPosition.getAccruedFunding(vars.fundingFeePerUnit));

        vars.newPosition = Position.Data({
            size: sd59x18(oldPosition.size).add(vars.sizeDelta).intoInt256(),
            lastInteractionPrice: vars.fillPrice.intoUint128(),
            lastInteractionFundingFeePerUnit: vars.fundingFeePerUnit.intoInt256().toInt128()
        });

        // TODO: Handle negative margin case
        if (vars.pnl.lt(SD_ZERO)) {
            UD60x18 amountToDeduct = vars.pnl.intoUD60x18();
            perpsAccount.deductAccountMargin(amountToDeduct);
        } else if (vars.pnl.gt(SD_ZERO)) {
            UD60x18 amountToIncrease = vars.pnl.intoUD60x18();
            perpsAccount.deposit(usdToken, amountToIncrease);
        }
        // TODO: liquidityEngine.withdrawUsdToken(upkeep, vars.marketId, vars.fee);

        perpsAccount.updateActiveMarkets(vars.marketId, sd59x18(oldPosition.size), sd59x18(vars.newPosition.size));
        if (vars.newPosition.size == 0) {
            oldPosition.clear();
        } else {
            oldPosition.update(vars.newPosition);
        }

        perpMarket.updateOpenInterest(vars.sizeDelta);

        emit LogSettleOrder(msg.sender, vars.accountId, vars.marketId, vars.pnl.intoInt256(), vars.newPosition);
    }

    function _requireIsSettlementStrategy(address sender, address upkeep) internal pure {
        if (sender != upkeep && upkeep != address(0)) {
            revert Errors.OnlyUpkeep(sender, upkeep);
        }
    }
}
