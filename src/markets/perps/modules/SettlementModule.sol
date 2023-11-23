// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

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

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

abstract contract SettlementModule is ISettlementModule {
    using Order for Order.Data;
    using PerpsAccount for PerpsAccount.Data;
    using PerpsMarket for PerpsMarket.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using SafeCast for int256;

    modifier onlyMarketOrderUpkeep() {
        address marketOrderUpkeep;
        if (msg.sender != marketOrderUpkeep) {
            revert Errors.OnlyForwarder(msg.sender, marketOrderUpkeep);
        }
        _;
    }

    function settleOrder(
        uint256 accountId,
        uint128 marketId,
        uint8 orderId,
        BasicReport calldata report
    )
        external
        onlyMarketOrderUpkeep
    {
        Order.Data storage order = PerpsMarket.load(marketId).orders[accountId][orderId];

        _settleOrder(order, report);
    }

    // TODO: many validations pending
    function _settleOrder(Order.Data storage order, BasicReport memory report) internal {
        SettlementRuntime memory runtime;
        runtime.marketId = order.payload.marketId;
        runtime.accountId = order.payload.accountId;

        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(runtime.marketId);
        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(runtime.accountId);
        Position.Data storage oldPosition = perpsMarket.positions[runtime.accountId];
        // address usdToken = PerpsConfiguration.load().usdToken;

        // TODO: apply price impact
        runtime.fillPrice = sd59x18(report.price).intoUD60x18();
        SD59x18 fundingFeePerUnit = perpsMarket.calculateNextFundingFeePerUnit(runtime.fillPrice);
        SD59x18 accruedFunding = oldPosition.getAccruedFunding(fundingFeePerUnit);
        SD59x18 currentUnrealizedPnl = oldPosition.getUnrealizedPnl(runtime.fillPrice, accruedFunding);
        // this will change
        runtime.pnl = currentUnrealizedPnl;
        runtime.unrealizedPnlToStore = sd59x18(0);

        // for now we'll realize the total uPnL, we should realize it proportionally in the future
        // if (runtime.pnl.lt(SD_ZERO)) {
        //     perpsAccount.deductAccountMargin(runtime.pnl.intoUD60x18());
        // } else if (runtime.pnl.gt(SD_ZERO)) {
        //     perpsAccount.increaseMarginCollateralBalance(usdToken, runtime.pnl.intoUD60x18());
        // }
        UD60x18 initialMargin =
            ud60x18(oldPosition.initialMargin).add(sd59x18(order.payload.initialMarginDelta).intoUD60x18());

        // TODO: validate initial margin and size
        runtime.newPosition = Position.Data({
            size: sd59x18(oldPosition.size).add(sd59x18(order.payload.sizeDelta)).intoInt256(),
            initialMargin: initialMargin.intoUint128(),
            unrealizedPnlStored: runtime.unrealizedPnlToStore.intoInt256().toInt128(),
            lastInteractionPrice: runtime.fillPrice.intoUint128(),
            lastInteractionFundingFeePerUnit: fundingFeePerUnit.intoInt256().toInt128()
        });

        order.reset();
        perpsAccount.updateActiveOrders(runtime.marketId, order.id, false);
        oldPosition.update(runtime.newPosition);
        perpsMarket.skew = sd59x18(perpsMarket.skew).add(sd59x18(order.payload.sizeDelta)).intoInt256().toInt128();
        perpsMarket.size =
            ud60x18(perpsMarket.size).add(sd59x18(order.payload.sizeDelta).abs().intoUD60x18()).intoUint128();

        emit LogSettleOrder(msg.sender, runtime.accountId, runtime.marketId, order.id, runtime.newPosition);
    }
}
