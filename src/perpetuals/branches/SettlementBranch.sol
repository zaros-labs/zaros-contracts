// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { LimitedMintingERC20 } from "@zaros/testnet/LimitedMintingERC20.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketOrder } from "../leaves/MarketOrder.sol";
import { TradingAccount } from "../leaves/TradingAccount.sol";
import { FeeRecipients } from "../leaves/FeeRecipients.sol";
import { GlobalConfiguration } from "../leaves/GlobalConfiguration.sol";
import { PerpMarket } from "../leaves/PerpMarket.sol";
import { Position } from "../leaves/Position.sol";
import { SettlementConfiguration } from "../leaves/SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { SafeERC20, IERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

contract SettlementBranch {
    using EnumerableSet for EnumerableSet.UintSet;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using MarketOrder for MarketOrder.Data;
    using TradingAccount for TradingAccount.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using SafeCast for int256;
    using SafeERC20 for IERC20;
    using SettlementConfiguration for SettlementConfiguration.Data;

    event LogFillOrder(
        address indexed sender,
        uint128 indexed tradingAccountId,
        uint128 indexed marketId,
        int256 sizeDelta,
        uint256 fillPrice,
        int256 orderFeeUsd,
        uint256 settlementFeeUsd,
        int256 pnl,
        int256 fundingFeePerUnit
    );

    modifier onlyCustomOrderKeeper(uint128 marketId, uint128 settlementConfigurationId) {
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, settlementConfigurationId);
        address keeper = settlementConfiguration.keeper;

        _requireIsKeeper(msg.sender, keeper);
        _;
    }

    modifier onlyMarketOrderKeeper(uint128 marketId) {
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID);
        address keeper = settlementConfiguration.keeper;

        _requireIsKeeper(msg.sender, keeper);
        _;
    }

    /// @param tradingAccountId The trading account id.
    /// @param marketId The perp market id.
    /// @param priceData The price data of market order.
    function fillMarketOrder(
        uint128 tradingAccountId,
        uint128 marketId,
        bytes calldata priceData
    )
        external
        onlyMarketOrderKeeper(marketId)
    {
        MarketOrder.Data storage marketOrder = MarketOrder.loadExisting(tradingAccountId);

        _fillOrder(
            tradingAccountId,
            marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            marketOrder.sizeDelta,
            priceData
        );

        marketOrder.clear();
    }

    struct SettlementPayload {
        uint128 tradingAccountId;
        int128 sizeDelta;
    }

    /// @param marketId The perp market id.
    /// @param settlementConfigurationId The perp market settlement configuration id.
    /// @param settlementFeeRecipient The settlement fee recipient.
    /// @param payloads The list of settlement payloads.
    /// @param priceData The price data of custom orders.
    /// @param callback The callback address.
    function fillCustomOrders(
        uint128 marketId,
        uint128 settlementConfigurationId,
        address settlementFeeRecipient,
        SettlementPayload[] calldata payloads,
        bytes calldata priceData,
        address callback
    )
        external
        onlyCustomOrderKeeper(marketId, settlementConfigurationId)
    {
        // // TODO: optimize this. We should be able to use the same market id and reports, and just loop on the
        // // position's
        // // validations and updates.
        // for (uint256 i = 0; i < payloads.length; i++) {
        //     SettlementPayload memory payload = payloads[i];

        //     _fillOrder(marketId, settlementConfigurationId, payload, priceData);
        // }

        // _paySettlementFees({
        //     settlementFeeRecipient: settlementFeeRecipient,
        //     marketId: marketId,
        //     settlementConfigurationId: settlementConfigurationId,
        //     amountOfSettledTrades: payloads.length
        // });

        // if (callback != address(0)) {
        //     ISettlementStrategy(callback).callback(payloads);
        // }

        // address ocoOrderSettlementStrategy = SettlementConfiguration.load(
        //     marketId, SettlementConfiguration.OCO_ORDER_CONFIGURATION_ID
        // ).settlementStrategy;
        // if (ocoOrderSettlementStrategy != address(0) && ocoOrderSettlementStrategy != msg.sender) {
        //     ISettlementStrategy(ocoOrderSettlementStrategy).callback(payloads);
        // }
    }

    struct FillOrderContext {
        address usdToken;
        uint128 marketId;
        uint128 tradingAccountId;
        SD59x18 orderFeeUsdX18;
        UD60x18 settlementFeeUsdX18;
        SD59x18 sizeDelta;
        UD60x18 fillPrice;
        SD59x18 pnl;
        SD59x18 fundingFeePerUnit;
        SD59x18 fundingRate;
        Position.Data newPosition;
        UD60x18 newOpenInterest;
        SD59x18 newSkew;
    }

    /// @param tradingAccountId The trading account id.
    /// @param marketId The perp market id.
    /// @param settlementConfigurationId The perp market settlement configuration id.
    /// @param sizeDelta The size delta of the order.
    /// @param priceData The price data of the order.
    function _fillOrder(
        uint128 tradingAccountId,
        uint128 marketId,
        uint128 settlementConfigurationId,
        int128 sizeDelta,
        bytes memory priceData
    )
        internal
        virtual
    {
        FillOrderContext memory ctx;
        ctx.marketId = marketId;
        ctx.tradingAccountId = tradingAccountId;
        ctx.sizeDelta = sd59x18(sizeDelta);

        PerpMarket.Data storage perpMarket = PerpMarket.load(ctx.marketId);
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(ctx.tradingAccountId);
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, settlementConfigurationId);
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        Position.Data storage oldPosition = Position.load(ctx.tradingAccountId, ctx.marketId);

        ctx.usdToken = globalConfiguration.usdToken;

        globalConfiguration.checkMarketIsEnabled(ctx.marketId);
        perpMarket.checkTradeSize(ctx.sizeDelta);

        ctx.fillPrice = perpMarket.getMarkPrice(
            ctx.sizeDelta, settlementConfiguration.verifyOffchainPrice(priceData, ctx.sizeDelta.gt(SD_ZERO))
        );

        ctx.fundingRate = perpMarket.getCurrentFundingRate();
        ctx.fundingFeePerUnit = perpMarket.getNextFundingFeePerUnit(ctx.fundingRate, ctx.fillPrice);

        perpMarket.updateFunding(ctx.fundingRate, ctx.fundingFeePerUnit);

        ctx.orderFeeUsdX18 = perpMarket.getOrderFeeUsd(ctx.sizeDelta, ctx.fillPrice);
        ctx.settlementFeeUsdX18 = ud60x18(uint256(settlementConfiguration.fee));

        {
            (UD60x18 requiredInitialMarginUsdX18,, SD59x18 accountTotalUnrealizedPnlUsdX18) =
                tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(marketId, ctx.sizeDelta);

            tradingAccount.validateMarginRequirement(
                requiredInitialMarginUsdX18,
                tradingAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18),
                ctx.orderFeeUsdX18.add(ctx.settlementFeeUsdX18.intoSD59x18())
            );
        }

        ctx.pnl = oldPosition.getUnrealizedPnl(ctx.fillPrice).add(
            oldPosition.getAccruedFunding(ctx.fundingFeePerUnit)
        ).add(unary(ctx.orderFeeUsdX18.add(ctx.settlementFeeUsdX18.intoSD59x18())));

        ctx.newPosition = Position.Data({
            size: sd59x18(oldPosition.size).add(ctx.sizeDelta).intoInt256(),
            lastInteractionPrice: ctx.fillPrice.intoUint128(),
            lastInteractionFundingFeePerUnit: ctx.fundingFeePerUnit.intoInt256().toInt128()
        });

        (ctx.newOpenInterest, ctx.newSkew) = perpMarket.checkOpenInterestLimits(
            ctx.sizeDelta, sd59x18(oldPosition.size), sd59x18(ctx.newPosition.size), true
        );
        perpMarket.updateOpenInterest(ctx.newOpenInterest, ctx.newSkew);

        tradingAccount.updateActiveMarkets(ctx.marketId, sd59x18(oldPosition.size), sd59x18(ctx.newPosition.size));

        if (ctx.newPosition.size == 0) {
            oldPosition.clear();
        } else {
            if (
                sd59x18(ctx.newPosition.size).abs().lt(
                    sd59x18(int256(uint256(perpMarket.configuration.minTradeSizeX18)))
                )
            ) {
                revert Errors.NewPositionSizeTooSmall();
            }
            oldPosition.update(ctx.newPosition);
        }

        if (ctx.pnl.lt(SD_ZERO)) {
            UD60x18 marginToDeductUsdX18 = ctx.orderFeeUsdX18.add(ctx.settlementFeeUsdX18.intoSD59x18()).gt(SD_ZERO)
                ? ctx.pnl.abs().intoUD60x18().sub(ctx.orderFeeUsdX18.intoUD60x18().add(ctx.settlementFeeUsdX18))
                : ctx.pnl.abs().intoUD60x18();

            tradingAccount.deductAccountMargin({
                feeRecipients: FeeRecipients.Data({
                    marginCollateralRecipient: globalConfiguration.marginCollateralRecipient,
                    orderFeeRecipient: globalConfiguration.orderFeeRecipient,
                    settlementFeeRecipient: globalConfiguration.settlementFeeRecipient
                }),
                pnlUsdX18: marginToDeductUsdX18,
                orderFeeUsdX18: ctx.orderFeeUsdX18.gt(SD_ZERO) ? ctx.orderFeeUsdX18.intoUD60x18() : UD_ZERO,
                settlementFeeUsdX18: ctx.settlementFeeUsdX18
            });
        } else if (ctx.pnl.gt(SD_ZERO)) {
            UD60x18 amountToIncrease = ctx.pnl.intoUD60x18();
            tradingAccount.deposit(ctx.usdToken, amountToIncrease);

            // NOTE: testnet only - will be updated once Liquidity Engine is finalized
            LimitedMintingERC20(ctx.usdToken).mint(address(this), amountToIncrease.intoUint256());
        }

        emit LogFillOrder(
            msg.sender,
            ctx.tradingAccountId,
            ctx.marketId,
            ctx.sizeDelta.intoInt256(),
            ctx.fillPrice.intoUint256(),
            ctx.orderFeeUsdX18.intoInt256(),
            ctx.settlementFeeUsdX18.intoUint256(),
            ctx.pnl.intoInt256(),
            ctx.fundingFeePerUnit.intoInt256()
        );
    }

    /// @param sender The sender address.
    /// @param keeper The keeper address.
    function _requireIsKeeper(address sender, address keeper) internal pure {
        if (sender != keeper && keeper != address(0)) {
            revert Errors.OnlyKeeper(sender, keeper);
        }
    }
}
