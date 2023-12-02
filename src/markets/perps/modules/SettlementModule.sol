// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { BasicReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { ISettlementModule } from "../interfaces/ISettlementModule.sol";
import { Order } from "../storage/Order.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { PerpsConfiguration } from "../storage/PerpsConfiguration.sol";
import { PerpsMarket } from "../storage/PerpsMarket.sol";
import { Position } from "../storage/Position.sol";
import { SettlementStrategy } from "../storage/SettlementStrategy.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

abstract contract SettlementModule is ISettlementModule {
    using Order for Order.Market;
    using PerpsAccount for PerpsAccount.Data;
    using PerpsMarket for PerpsMarket.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using SafeCast for int256;

    modifier onlyMarketOrderUpkeep(uint128 marketId) {
        SettlementStrategy.Data storage marketOrderStrategy = PerpsMarket.load(marketId).marketOrderStrategy;
        address upkeep = marketOrderStrategy.upkeep;

        if (msg.sender != upkeep && upkeep != address(0)) {
            revert Errors.OnlyForwarder(msg.sender, upkeep);
        }
        _;
    }

    function settleMarketOrder(
        uint128 accountId,
        uint128 marketId,
        BasicReport calldata report
    )
        external
        onlyMarketOrderUpkeep(marketId)
    {
        Order.Market storage marketOrder = PerpsAccount.load(accountId).activeMarketOrder[marketId];

        _settleMarketOrder(marketOrder, report);
    }

    // TODO: rework this
    function _settleMarketOrder(Order.Market storage marketOrder, BasicReport memory report) internal {
        SettlementRuntime memory runtime;
        runtime.marketId = marketOrder.payload.marketId;
        runtime.accountId = marketOrder.payload.accountId;

        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(runtime.marketId);
        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(runtime.accountId);
        Position.Data storage oldPosition = perpsMarket.positions[runtime.accountId];
        runtime.settlementFee = ud60x18(perpsMarket.marketOrderStrategy.settlementFee);
        address usdToken = PerpsConfiguration.load().usdToken;

        // TODO: apply price impact
        runtime.fillPrice = sd59x18(report.price).intoUD60x18();
        SD59x18 fundingFeePerUnit = perpsMarket.calculateNextFundingFeePerUnit(runtime.fillPrice);
        SD59x18 accruedFunding = oldPosition.getAccruedFunding(fundingFeePerUnit);
        SD59x18 currentUnrealizedPnl = oldPosition.getUnrealizedPnl(runtime.fillPrice, accruedFunding);
        // this will change
        runtime.pnl = currentUnrealizedPnl;
        runtime.unrealizedPnlToStore = sd59x18(0);

        // for now we'll realize the total uPnL, we should realize it proportionally in the future
        if (runtime.pnl.lt(SD_ZERO)) {
            UD60x18 amountToDeduct = runtime.pnl.intoUD60x18().add((runtime.settlementFee));
            perpsAccount.deductAccountMargin(amountToDeduct);
        } else if (runtime.pnl.gt(SD_ZERO)) {
            UD60x18 amountToIncrease = runtime.pnl.intoUD60x18().sub((runtime.settlementFee));
            perpsAccount.increaseMarginCollateralBalance(usdToken, amountToIncrease);
        }
        // TODO: liquidityEngine.withdrawUsdToken(upkeep, runtime.marketId, runtime.settlementFee);

        // UD60x18 initialMargin =
        //     ud60x18(oldPosition.initialMargin).add(sd59x18(marketOrder.payload.initialMarginDelta).intoUD60x18());

        // TODO: validate initial margin and size
        runtime.newPosition = Position.Data({
            size: sd59x18(oldPosition.size).add(sd59x18(marketOrder.payload.sizeDelta)).intoInt256(),
            // initialMargin: initialMargin.intoUint128(),
            initialMargin: 0,
            unrealizedPnlStored: runtime.unrealizedPnlToStore.intoInt256().toInt128(),
            lastInteractionPrice: runtime.fillPrice.intoUint128(),
            lastInteractionFundingFeePerUnit: fundingFeePerUnit.intoInt256().toInt128()
        });

        marketOrder.reset();
        // perpsAccount.updateActiveOrders(runtime.marketId, marketOrder.id, false);
        oldPosition.update(runtime.newPosition);
        perpsMarket.skew = sd59x18(perpsMarket.skew).add(sd59x18(marketOrder.payload.sizeDelta)).intoInt256().toInt128();
        perpsMarket.size =
            ud60x18(perpsMarket.size).add(sd59x18(marketOrder.payload.sizeDelta).abs().intoUD60x18()).intoUint128();

        emit LogSettleOrder(msg.sender, runtime.accountId, runtime.marketId, runtime.newPosition);
    }
}
