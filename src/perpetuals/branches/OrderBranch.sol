// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";
import { TradingAccount } from "@zaros/perpetuals/leaves/TradingAccount.sol";
import { GlobalConfiguration } from "@zaros/perpetuals/leaves/GlobalConfiguration.sol";
import { PerpMarket } from "@zaros/perpetuals/leaves/PerpMarket.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD59x18_ZERO  } from "@prb-math/SD59x18.sol";

contract OrderBranch {
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using MarketOrder for MarketOrder.Data;
    using TradingAccount for TradingAccount.Data;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;

    /// @notice Emitted when a market order is created.
    /// @param sender The account that created the market order.
    /// @param tradingAccountId The trading account id.
    /// @param marketId The perp market id.
    /// @param marketOrder The market order data.
    event LogCreateMarketOrder(
        address indexed sender,
        uint128 indexed tradingAccountId,
        uint128 indexed marketId,
        MarketOrder.Data marketOrder
    );
    /// @notice Emitted when a market order is cancelled.
    /// @param sender The account that cancelled the market order.
    /// @param tradingAccountId The trading account id.
    event LogCancelMarketOrder(address indexed sender, uint128 indexed tradingAccountId);

    /// @param marketId The perp market id.
    /// @return The order fees for the given market.
    function getConfiguredOrderFees(uint128 marketId) external view returns (OrderFees.Data memory) {
        return PerpMarket.load(marketId).configuration.orderFees;
    }

    struct SimulateTradeContext {
        SD59x18 sizeDeltaX18;
        SD59x18 accountTotalUnrealizedPnlUsdX18;
        UD60x18 previousRequiredMaintenanceMarginUsdX18;
        SD59x18 newPositionSizeX18;
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
            UD60x18 orderFeeUsdX18,
            UD60x18 settlementFeeUsdX18,
            UD60x18 fillPriceX18
        )
    {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, settlementConfigurationId);

        SimulateTradeContext memory ctx;

        ctx.sizeDeltaX18 = sd59x18(sizeDelta);

        fillPriceX18 = perpMarket.getMarkPrice(ctx.sizeDeltaX18, perpMarket.getIndexPrice());

        orderFeeUsdX18 = perpMarket.getOrderFeeUsd(ctx.sizeDeltaX18, fillPriceX18);

        settlementFeeUsdX18 = ud60x18(uint256(settlementConfiguration.fee));

        (requiredInitialMarginUsdX18, requiredMaintenanceMarginUsdX18, ctx.accountTotalUnrealizedPnlUsdX18) =
            tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(marketId, ctx.sizeDeltaX18);
        marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(ctx.accountTotalUnrealizedPnlUsdX18);
        {
            (, ctx.previousRequiredMaintenanceMarginUsdX18,) =
                tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(0, SD59x18_ZERO);

            if (TradingAccount.isLiquidatable(ctx.previousRequiredMaintenanceMarginUsdX18, marginBalanceUsdX18)) {
                revert Errors.AccountIsLiquidatable(tradingAccountId);
            }
        }
        {
            Position.Data storage position = Position.load(tradingAccountId, marketId);

            ctx.newPositionSizeX18 = sd59x18(position.size).add(ctx.sizeDeltaX18);

            if (
                !ctx.newPositionSizeX18.isZero()
                    && ctx.newPositionSizeX18.abs().lt(sd59x18(int256(uint256(perpMarket.configuration.minTradeSizeX18))))
            ) {
                revert Errors.NewPositionSizeTooSmall();
            }
        }
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

    /// @param tradingAccountId The trading account id creating the market order
    /// @param marketId The perp market id
    /// @param sizeDelta The size delta of the order
    struct CreateMarketOrderParams {
        uint128 tradingAccountId;
        uint128 marketId;
        int128 sizeDelta;
    }

    struct CreateMarketOrderContext {
        SD59x18 marginBalanceUsdX18;
        UD60x18 requiredInitialMarginUsdX18;
        UD60x18 orderFeeUsdX18;
        UD60x18 settlementFeeUsdX18;
    }

    /// @notice Creates a market order for the given trading account and market ids.
    /// @dev See {CreateMarketOrderParams}.
    function createMarketOrder(CreateMarketOrderParams calldata params) external {
        if (params.sizeDelta == 0) {
            revert Errors.ZeroInput("sizeDelta");
        }
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        bool isIncreasingPosition =
            Position.isIncreasingPosition(params.tradingAccountId, params.marketId, params.sizeDelta);

        // Check if market is enabled only if the position is being opened or increased
        if (isIncreasingPosition) {
            globalConfiguration.checkMarketIsEnabled(params.marketId);
        }

        Position.Data storage position = Position.load(params.tradingAccountId, params.marketId);

        TradingAccount.Data storage tradingAccount =
            TradingAccount.loadExistingAccountAndVerifySender(params.tradingAccountId);
        bool isMarketWithActivePosition = tradingAccount.isMarketWithActivePosition(params.marketId);
        if (!isMarketWithActivePosition) {
            tradingAccount.validatePositionsLimit();
        }

        PerpMarket.Data storage perpMarket = PerpMarket.load(params.marketId);
        perpMarket.checkTradeSize(sd59x18(params.sizeDelta));
        perpMarket.checkOpenInterestLimits(
            sd59x18(params.sizeDelta),
            sd59x18(position.size),
            sd59x18(position.size).add(sd59x18(params.sizeDelta)),
            true
        );

        MarketOrder.Data storage marketOrder = MarketOrder.load(params.tradingAccountId);

        CreateMarketOrderContext memory ctx;

        (ctx.marginBalanceUsdX18, ctx.requiredInitialMarginUsdX18,, ctx.orderFeeUsdX18, ctx.settlementFeeUsdX18,) =
        simulateTrade({
            tradingAccountId: params.tradingAccountId,
            marketId: params.marketId,
            settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            sizeDelta: params.sizeDelta
        });
        tradingAccount.validateMarginRequirement(
            ctx.requiredInitialMarginUsdX18, ctx.marginBalanceUsdX18, ctx.orderFeeUsdX18.add(ctx.settlementFeeUsdX18)
        );

        marketOrder.checkPendingOrder();
        marketOrder.update({ marketId: params.marketId, sizeDelta: params.sizeDelta });

        emit LogCreateMarketOrder(msg.sender, params.tradingAccountId, params.marketId, marketOrder);
    }

    /// @notice Cancels an active market order.
    /// @dev Reverts if the sender is not the trading account or if there is no active market order for the
    /// given account and market.
    /// @param tradingAccountId The trading account id.
    function cancelMarketOrder(uint128 tradingAccountId) external {
        TradingAccount.loadExistingAccountAndVerifySender(tradingAccountId);

        MarketOrder.Data storage marketOrder = MarketOrder.loadExisting(tradingAccountId);

        marketOrder.checkPendingOrder();

        marketOrder.clear();

        emit LogCancelMarketOrder(msg.sender, tradingAccountId);
    }
}
