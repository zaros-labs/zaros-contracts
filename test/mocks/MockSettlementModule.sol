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

        // globalConfiguration.checkMarketIsEnabled(vars.marketId);
        // TODO: Handle state validation without losing the gas fee potentially paid by CL automation.
        // TODO: potentially update all checks to return true / false and bubble up the revert to the caller?
        // perpsAccount.checkIsNotLiquidatable();
        perpMarket.validateNewState(vars.sizeDelta);

        UD60x18 indexPriceX18 = perpMarket.getIndexPrice();
        vars.fillPrice = perpMarket.getMarkPrice(vars.sizeDelta, indexPriceX18);

        vars.totalFeesUsdX18 = perpMarket.getOrderFeeUsd(vars.sizeDelta, vars.fillPrice).add(
            ud60x18(uint256(settlementConfiguration.fee)).intoSD59x18()
        );

        perpsAccount.validateMarginRequirements(vars.marketId, vars.sizeDelta, vars.totalFeesUsdX18);

        vars.fundingRate = perpMarket.getCurrentFundingRate();
        vars.fundingFeePerUnit = perpMarket.getNextFundingFeePerUnit(vars.fundingRate, vars.fillPrice);

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

        perpMarket.updateState(vars.sizeDelta, vars.fundingRate, vars.fundingFeePerUnit);

        emit LogSettleOrder(msg.sender, vars.accountId, vars.marketId, vars.pnl.intoInt256(), vars.newPosition);
    }
}
