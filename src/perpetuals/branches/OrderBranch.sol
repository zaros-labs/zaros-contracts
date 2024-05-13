// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketOrder } from "../leaves/MarketOrder.sol";
import { OrderFees } from "../leaves/OrderFees.sol";
import { TradingAccount } from "../leaves/TradingAccount.sol";
import { GlobalConfiguration } from "../leaves/GlobalConfiguration.sol";
import { PerpMarket } from "../leaves/PerpMarket.sol";
import { Position } from "../leaves/Position.sol";
import { SettlementConfiguration } from "../leaves/SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

import { console } from "forge-std/console.sol";

contract OrderBranch {
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using MarketOrder for MarketOrder.Data;
    using TradingAccount for TradingAccount.Data;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;

    event LogCreateMarketOrder(
        address indexed sender,
        uint128 indexed tradingAccountId,
        uint128 indexed marketId,
        MarketOrder.Data marketOrder
    );
    event LogCancelMarketOrder(address indexed sender, uint128 indexed tradingAccountId);

    /// @param marketId The perp market id.
    /// @return The order fees for the given market.
    function getConfiguredOrderFees(uint128 marketId) external view returns (OrderFees.Data memory) {
        return PerpMarket.load(marketId).configuration.orderFees;
    }

    /// @notice Simulates the settlement costs and validity of a given order.
    /// @dev Reverts if there's not enough margin to cover the trade.
    /// @param tradingAccountId The trading account id.
    /// @param marketId The perp market id.
    /// @param settlementConfigurationId The perp market settlement configuration id.
    /// @param sizeDelta The size delta of the order.
    /// @return marginBalanceUsdX18 The given account's current margin balance.
    /// @return requiredInitialMarginUsdX18 The required initial margin to settle the given trade.
    /// @return requiredMaintenanceMarginUsdX18 The required maintenance margin to settle the given trade.
    /// @return orderFeeUsdX18 The order fee in USD.
    /// @return settlementFeeUsdX18 The settlement fee in USD.
    /// @return fillPriceX18 The fill price quote.
    function simulateTrade(
        uint128 tradingAccountId,
        uint128 marketId,
        uint128 settlementConfigurationId,
        int128 sizeDelta
    )
        public
        view
        returns (
            SD59x18 marginBalanceUsdX18,
            UD60x18 requiredInitialMarginUsdX18,
            UD60x18 requiredMaintenanceMarginUsdX18,
            SD59x18 orderFeeUsdX18,
            UD60x18 settlementFeeUsdX18,
            UD60x18 fillPriceX18
        )
    {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, settlementConfigurationId);

        fillPriceX18 = perpMarket.getMarkPrice(sd59x18(sizeDelta), perpMarket.getIndexPrice());

        orderFeeUsdX18 = perpMarket.getOrderFeeUsd(sd59x18(sizeDelta), fillPriceX18);
        settlementFeeUsdX18 = ud60x18(uint256(settlementConfiguration.fee));

        SD59x18 accountTotalUnrealizedPnlUsdX18;
        (requiredInitialMarginUsdX18, requiredMaintenanceMarginUsdX18, accountTotalUnrealizedPnlUsdX18) =
            tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(marketId, sd59x18(sizeDelta));
        marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18);
        {
            // GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
            // UD60x18 liquidationFeeUsdX18 = ud60x18(globalConfiguration.liquidationFeeUsdX18);
            (, UD60x18 previousRequiredMaintenanceMarginUsdX18,) =
                tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(0, sd59x18(0));
            // console.log("simulate trade values: ");
            // console.log(marginBalanceUsdX18.intoUD60x18().intoUint256());
            // console.log(previousRequiredMaintenanceMarginUsdX18.intoUint256());

            if (TradingAccount.isLiquidatable(previousRequiredMaintenanceMarginUsdX18, marginBalanceUsdX18)) {
                revert Errors.AccountIsLiquidatable(tradingAccountId);
            }
        }
        // {
        //     Position.Data storage position = Position.load(tradingAccountId, marketId);
        //     SD59x18 newPositionSizeX18 = sd59x18(position.size).add(sd59x18(sizeDelta));

        //     if (newPositionSizeX18.abs().lt(sd59x18(int256(perpMarket.configuration.minTradeSizeX18)))) {
        //         revert Errors.NewPositionSizeTooSmall();
        //     }
        // }
    }

    /// @param marketId The perp market id.
    /// @param sizeDelta The size delta of the order.
    /// @return initialMarginUsdX18 The initial margin requirement for the given trade.
    /// @return maintenanceMarginUsdX18 The maintenance margin requirement for the given trade.
    function getMarginRequirementForTrade(
        uint128 marketId,
        int128 sizeDelta
    )
        external
        view
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

    /// @param tradingAccountId The trading account id to get the active market
    function getActiveMarketOrder(uint128 tradingAccountId) external pure returns (MarketOrder.Data memory) {
        MarketOrder.Data storage marketOrder = MarketOrder.load(tradingAccountId);

        return marketOrder;
    }

    struct CreateMarketOrderParams {
        uint128 tradingAccountId;
        uint128 marketId;
        int128 sizeDelta;
    }

    struct CreateMarketOrderContext {
        SD59x18 marginBalanceUsdX18;
        UD60x18 requiredInitialMarginUsdX18;
        UD60x18 requiredMaintenanceMarginUsdX18;
        SD59x18 orderFeeUsdX18;
        UD60x18 settlementFeeUsdX18;
    }

    /// @dev See {CreateMarketOrderParams}.
    function createMarketOrder(CreateMarketOrderParams calldata params) external {
        TradingAccount.Data storage tradingAccount =
            TradingAccount.loadExistingAccountAndVerifySender(params.tradingAccountId);
        PerpMarket.Data storage perpMarket = PerpMarket.load(params.marketId);
        MarketOrder.Data storage marketOrder = MarketOrder.load(params.tradingAccountId);
        Position.Data storage position = Position.load(params.tradingAccountId, params.marketId);
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        CreateMarketOrderContext memory ctx;

        if (params.sizeDelta == 0) {
            revert Errors.ZeroInput("sizeDelta");
        }

        globalConfiguration.checkMarketIsEnabled(params.marketId);

        perpMarket.checkTradeSize(sd59x18(params.sizeDelta));
        perpMarket.checkOpenInterestLimits(
            sd59x18(params.sizeDelta), sd59x18(position.size), sd59x18(position.size).add(sd59x18(params.sizeDelta))
        );

        bool isMarketWithActivePosition = tradingAccount.isMarketWithActivePosition(params.marketId);
        if (!isMarketWithActivePosition) {
            tradingAccount.validatePositionsLimit();
        }

        (
            ctx.marginBalanceUsdX18,
            ctx.requiredInitialMarginUsdX18,
            ctx.requiredMaintenanceMarginUsdX18,
            ctx.orderFeeUsdX18,
            ctx.settlementFeeUsdX18,
        ) = simulateTrade({
            tradingAccountId: params.tradingAccountId,
            marketId: params.marketId,
            settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            sizeDelta: params.sizeDelta
        });
        tradingAccount.validateMarginRequirement(
            ctx.requiredInitialMarginUsdX18.add(ctx.requiredMaintenanceMarginUsdX18),
            ctx.marginBalanceUsdX18,
            ctx.orderFeeUsdX18.add(ctx.settlementFeeUsdX18.intoSD59x18())
        );

        marketOrder.checkPendingOrder();
        marketOrder.update({ marketId: params.marketId, sizeDelta: params.sizeDelta });

        emit LogCreateMarketOrder(msg.sender, params.tradingAccountId, params.marketId, marketOrder);
    }

    /// @notice Cancels an active market order.
    /// @dev Reverts if there is no active market order for the given account and market.
    /// @param tradingAccountId The trading account id.
    function cancelMarketOrder(uint128 tradingAccountId) external {
        MarketOrder.Data storage marketOrder = MarketOrder.loadExisting(tradingAccountId);

        marketOrder.clear();

        emit LogCancelMarketOrder(msg.sender, tradingAccountId);
    }
}
