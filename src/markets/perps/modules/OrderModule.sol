// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { ISettlementStrategy } from "@zaros/markets/settlement/interfaces/ISettlementStrategy.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IOrderModule } from "../interfaces/IOrderModule.sol";
import { MarketOrder } from "../storage/MarketOrder.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { GlobalConfiguration } from "../storage/GlobalConfiguration.sol";
import { PerpMarket } from "../storage/PerpMarket.sol";
import { Position } from "../storage/Position.sol";
import { SettlementConfiguration } from "../storage/SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

import "forge-std/console.sol";

contract OrderModule is IOrderModule {
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using MarketOrder for MarketOrder.Data;
    using PerpsAccount for PerpsAccount.Data;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;

    /// @inheritdoc IOrderModule
    function getConfiguredOrderFees(uint128 marketId) external view override returns (OrderFees.Data memory) {
        return PerpMarket.load(marketId).configuration.orderFees;
    }

    /// @inheritdoc IOrderModule
    function simulateTrade(
        uint128 accountId,
        uint128 marketId,
        uint128 settlementId,
        int128 sizeDelta
    )
        public
        view
        override
        returns (
            SD59x18 marginBalanceUsdX18,
            UD60x18 requiredInitialMarginUsdX18,
            UD60x18 requiredMaintenanceMarginUsdX18,
            SD59x18 orderFeeUsdX18,
            UD60x18 settlementFeeUsdX18,
            UD60x18 fillPriceX18
        )
    {
        PerpsAccount.Data storage perpsAccount = PerpsAccount.loadExisting(accountId);
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, settlementId);

        fillPriceX18 = perpMarket.getMarkPrice(sd59x18(sizeDelta), perpMarket.getIndexPrice());

        {
            GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
            globalConfiguration.checkTradeSizeUsd(sd59x18(sizeDelta), fillPriceX18);
        }

        orderFeeUsdX18 = perpMarket.getOrderFeeUsd(sd59x18(sizeDelta), fillPriceX18);
        settlementFeeUsdX18 = ud60x18(uint256(settlementConfiguration.fee));

        {
            SD59x18 accountTotalUnrealizedPnlUsdX18;
            (requiredInitialMarginUsdX18, requiredMaintenanceMarginUsdX18, accountTotalUnrealizedPnlUsdX18) =
                perpsAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(marketId, sd59x18(sizeDelta));
            marginBalanceUsdX18 = perpsAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18);

            console.log("CHIDORI");
            console.log(accountTotalUnrealizedPnlUsdX18.intoUD60x18().intoUint256());
            console.log(requiredInitialMarginUsdX18.intoUint256(), requiredMaintenanceMarginUsdX18.intoUint256());
            console.log(marginBalanceUsdX18.intoUD60x18().intoUint256());
            console.log(orderFeeUsdX18.add(settlementFeeUsdX18.intoSD59x18()).intoUD60x18().intoUint256());
        }
    }

    /// @inheritdoc IOrderModule
    function getMarginRequirementsForTrade(
        uint128 marketId,
        int128 sizeDelta
    )
        external
        view
        override
        returns (UD60x18, UD60x18)
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);

        UD60x18 indexPriceX18 = perpMarket.getIndexPrice();
        UD60x18 markPriceX18 = perpMarket.getMarkPrice(sd59x18(sizeDelta), indexPriceX18);

        UD60x18 orderValueX18 = markPriceX18.mul(sd59x18(sizeDelta).abs().intoUD60x18());
        UD60x18 initialMarginUsdX18 = orderValueX18.mul(ud60x18(perpMarket.configuration.initialMarginRateX18));
        UD60x18 maintenanceMarginUsdX18 =
            orderValueX18.mul(ud60x18(perpMarket.configuration.maintenanceMarginRateX18));

        return (initialMarginUsdX18, maintenanceMarginUsdX18);
    }

    /// @inheritdoc IOrderModule
    function getActiveMarketOrder(uint128 accountId) external pure override returns (MarketOrder.Data memory) {
        MarketOrder.Data storage marketOrder = MarketOrder.load(accountId);

        return marketOrder;
    }

    /// @inheritdoc IOrderModule
    function createMarketOrder(
        uint128 accountId,
        uint128 marketId,
        int128 sizeDelta,
        uint128 acceptablePrice
    )
        external
        override
    {
        PerpsAccount.Data storage perpsAccount = PerpsAccount.loadExistingAccountAndVerifySender(accountId);
        MarketOrder.Data storage marketOrder = MarketOrder.load(accountId);
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        if (sizeDelta == 0) {
            revert Errors.ZeroInput("sizeDelta");
        }

        (
            SD59x18 marginBalanceUsdX18,
            UD60x18 requiredInitialMarginUsdX18,
            UD60x18 requiredMaintenanceMarginUsdX18,
            SD59x18 orderFeeUsdX18,
            UD60x18 settlementFeeUsdX18,
        ) = simulateTrade({
            accountId: accountId,
            marketId: marketId,
            settlementId: SettlementConfiguration.MARKET_ORDER_SETTLEMENT_ID,
            sizeDelta: sizeDelta
        });
        perpsAccount.validateMarginRequirement(
            requiredInitialMarginUsdX18.add(requiredMaintenanceMarginUsdX18),
            marginBalanceUsdX18,
            orderFeeUsdX18.add(settlementFeeUsdX18.intoSD59x18())
        );

        bool isMarketWithActivePosition = perpsAccount.isMarketWithActivePosition(marketId);
        if (!isMarketWithActivePosition) {
            perpsAccount.validatePositionsLimit();
        }

        globalConfiguration.checkMarketIsEnabled(marketId);
        marketOrder.checkPendingOrder();

        marketOrder.update({ marketId: marketId, sizeDelta: sizeDelta, acceptablePrice: acceptablePrice });

        emit LogCreateMarketOrder(msg.sender, accountId, marketId, marketOrder);
    }

    function createCustomOrder(
        uint128 accountId,
        uint128 marketId,
        uint128 settlementId,
        bool isAccountStrategy,
        bytes calldata extraData
    )
        external
        override
        returns (bytes memory)
    {
        PerpsAccount.verifySender(accountId);
        SettlementConfiguration.Data storage settlementConfiguration;

        if (!isAccountStrategy) {
            settlementConfiguration = SettlementConfiguration.load(marketId, settlementId);
        } else {
            // TODO: Implement
            // settlementConfiguration = SettlementConfiguration.load(accountId, marketId, settlementId);
            settlementConfiguration = SettlementConfiguration.load(marketId, settlementId);
        }

        address settlementStrategy = settlementConfiguration.settlementStrategy;

        bytes memory callData = abi.encodeWithSelector(ISettlementStrategy.dispatch.selector, accountId, extraData);
        (bool success, bytes memory returnData) = settlementStrategy.call(callData);

        if (!success) {
            if (returnData.length == 0) revert Errors.FailedCreateCustomOrder();
            assembly {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }

        return returnData;
    }

    /// @inheritdoc IOrderModule
    function cancelMarketOrder(uint128 accountId) external override {
        MarketOrder.Data storage marketOrder = MarketOrder.loadExisting(accountId);

        marketOrder.clear();

        emit LogCancelMarketOrder(msg.sender, accountId);
    }
}
