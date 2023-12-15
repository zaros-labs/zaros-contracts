// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { BasicReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { ISettlementModule } from "../interfaces/ISettlementModule.sol";
import { MarketOrder } from "../storage/MarketOrder.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { PerpsConfiguration } from "../storage/PerpsConfiguration.sol";
import { PerpsMarket } from "../storage/PerpsMarket.sol";
import { Position } from "../storage/Position.sol";
import { SettlementConfiguration } from "../storage/SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

abstract contract SettlementModule is ISettlementModule {
    using MarketOrder for MarketOrder.Data;
    using PerpsAccount for PerpsAccount.Data;
    using PerpsMarket for PerpsMarket.Data;
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
        MarketOrder.Data storage marketOrder = PerpsAccount.load(accountId).activeMarketOrder[marketId];

        SettlementPayload memory payload = SettlementPayload({ accountId: accountId, sizeDelta: marketOrder.sizeDelta });
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
        // TODO: optimize this. We should be able to use the same market id and reports, and just loop on the position's
        // validations and updates.
        for (uint256 i = 0; i < payloads.length; i++) {
            SettlementPayload memory payload = payloads[i];

            _settle(marketId, settlementId, payload, extraData);
        }
    }

    // TODO: rework this
    function _settle(
        uint128 marketId,
        uint128 settlementId,
        SettlementPayload memory payload,
        bytes memory extraData
    )
        internal
    {
        SettlementRuntime memory runtime;
        runtime.marketId = marketId;
        runtime.accountId = payload.accountId;

        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(runtime.marketId);
        PerpsAccount.Data storage perpsAccount = PerpsAccount.load(runtime.accountId);
        Position.Data storage oldPosition = Position.load(runtime.accountId, runtime.marketId);
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, settlementId);
        runtime.fee = ud60x18(settlementConfiguration.fee);
        address usdToken = PerpsConfiguration.load().usdToken;

        // TODO: Let's find a better and defintitive way to avoid stack too deep.
        {
            bytes memory verifiedExtraData = settlementConfiguration.verifyExtraData(extraData);

            // TODO: apply price impact
            runtime.fillPrice = perpsMarket.getMarkPrice(extraData);
        }

        SD59x18 fundingFeePerUnit = perpsMarket.calculateNextFundingFeePerUnit(runtime.fillPrice);
        SD59x18 accruedFunding = oldPosition.getAccruedFunding(fundingFeePerUnit);
        SD59x18 currentUnrealizedPnl = oldPosition.getUnrealizedPnl(runtime.fillPrice, accruedFunding);
        // this will change
        runtime.pnl = currentUnrealizedPnl;
        runtime.unrealizedPnlToStore = sd59x18(0);

        // for now we'll realize the total uPnL, we should realize it proportionally in the future
        if (runtime.pnl.lt(SD_ZERO)) {
            UD60x18 amountToDeduct = runtime.pnl.intoUD60x18().add((runtime.fee));
            perpsAccount.deductAccountMargin(amountToDeduct);
        } else if (runtime.pnl.gt(SD_ZERO)) {
            UD60x18 amountToIncrease = runtime.pnl.intoUD60x18().sub((runtime.fee));
            perpsAccount.increaseMarginCollateralBalance(usdToken, amountToIncrease);
        }
        // TODO: liquidityEngine.withdrawUsdToken(upkeep, runtime.marketId, runtime.fee);

        // UD60x18 initialMargin =
        //     ud60x18(oldPosition.initialMargin).add(sd59x18(marketOrder.payload.initialMarginDelta).intoUD60x18());

        // TODO: validate initial margin and size
        runtime.newPosition = Position.Data({
            size: sd59x18(oldPosition.size).add(sd59x18(payload.sizeDelta)).intoInt256(),
            // initialMargin: initialMargin.intoUint128(),
            initialMargin: 0,
            unrealizedPnlStored: runtime.unrealizedPnlToStore.intoInt256().toInt128(),
            lastInteractionPrice: runtime.fillPrice.intoUint128(),
            lastInteractionFundingFeePerUnit: fundingFeePerUnit.intoInt256().toInt128()
        });

        oldPosition.update(runtime.newPosition);
        perpsMarket.skew = sd59x18(perpsMarket.skew).add(sd59x18(payload.sizeDelta)).intoInt256().toInt128();
        perpsMarket.size = ud60x18(perpsMarket.size).add(sd59x18(payload.sizeDelta).abs().intoUD60x18()).intoUint128();

        emit LogSettleOrder(msg.sender, runtime.accountId, runtime.marketId, runtime.newPosition);
    }

    function _requireIsSettlementStrategy(address sender, address upkeep) internal pure {
        if (sender != upkeep && upkeep != address(0)) {
            revert Errors.OnlyUpkeep(sender, upkeep);
        }
    }
}
