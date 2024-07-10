// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { LimitedMintingERC20 } from "testnet/LimitedMintingERC20.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { OffchainOrder } from "@zaros/perpetuals/leaves/OffchainOrder.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";
import { TradingAccount } from "@zaros/perpetuals/leaves/TradingAccount.sol";
import { FeeRecipients } from "@zaros/perpetuals/leaves/FeeRecipients.sol";
import { GlobalConfiguration } from "@zaros/perpetuals/leaves/GlobalConfiguration.sol";
import { PerpMarket } from "@zaros/perpetuals/leaves/PerpMarket.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// Open Zeppelin Upgradeable dependencies
import { EIP712Upgradeable } from "@openzeppelin-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD60x18_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD59x18_ZERO, unary } from "@prb-math/SD59x18.sol";

contract SettlementBranch is EIP712Upgradeable {
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

    constructor() {
        _disableInitializers();
    }

    /// @notice Emitted when a order is filled.
    /// @param sender The `msg.sender` address.
    /// @param tradingAccountId The trading account id that created the order.
    /// @param marketId The id of the perp market being settled.
    /// @param sizeDelta The size delta of the order.
    /// @param fillPrice The price at which the order was filled.
    /// @param orderFeeUsd The order fee in USD.
    /// @param settlementFeeUsd The settlement fee in USD.
    /// @param pnl The realized profit or loss.
    /// @param fundingFeePerUnit The funding fee per unit of the market being settled.
    event LogFillOrder(
        address indexed sender,
        uint128 indexed tradingAccountId,
        uint128 indexed marketId,
        int256 sizeDelta,
        uint256 fillPrice,
        uint256 orderFeeUsd,
        uint256 settlementFeeUsd,
        int256 pnl,
        int256 fundingFeePerUnit
    );

    modifier onlyMarketOrderKeeper(uint128 marketId) {
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID);
        address keeper = settlementConfiguration.keeper;

        _requireIsKeeper(msg.sender, keeper);
        _;
    }

    modifier onlyOffchainOrdersKeeper(uint128 marketId) {
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, SettlementConfiguration.OFFCHAIN_ORDERS_CONFIGURATION_ID);
        address keeper = settlementConfiguration.keeper;

        _requireIsKeeper(msg.sender, keeper);
        _;
    }

    /// @dev {SettlementBranch}  UUPS initializer.
    function initialize() external initializer {
        __EIP712_init(Constants.SETTLEMENT_BRANCH_DOMAIN_NAME, Constants.SETTLEMENT_BRANCH_DOMAIN_VERSION);
    }

    struct FillMarketOrder_Context {
        UD60x18 bidX18;
        UD60x18 askX18;
        SD59x18 sizeDeltaX18;
        bool isBuyOrder;
        UD60x18 indexPriceX18;
        UD60x18 fillPriceX18;
    }

    /// @notice Fills a pending market order created by the given trading account id at a given market id.
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
        FillMarketOrder_Context memory ctx;

        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID);
        MarketOrder.Data storage marketOrder = MarketOrder.loadExisting(tradingAccountId);

        if (marketId != marketOrder.marketId) {
            revert Errors.OrderMarketIdMismatch(marketId, marketOrder.marketId);
        }

        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        (ctx.bidX18, ctx.askX18) = settlementConfiguration.verifyOffchainPrice(priceData);

        // cache the order's size delta
        ctx.sizeDeltaX18 = sd59x18(marketOrder.sizeDelta);

        // cache the order side
        ctx.isBuyOrder = ctx.sizeDeltaX18.gt(SD59x18_ZERO);
        // if it's a buy order, we need to match against the ask price, if it's a sell order, we need to match
        // agaainst the bid price.
        ctx.indexPriceX18 = ctx.isBuyOrder ? ctx.askX18 : ctx.bidX18;

        // verify the provided price data against the verifier and ensure it's valid, then get the mark price
        // based on the returned index price.
        ctx.fillPriceX18 = perpMarket.getMarkPrice(ctx.sizeDeltaX18, ctx.indexPriceX18);

        _fillOrder(
            tradingAccountId,
            marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            ctx.sizeDeltaX18,
            ctx.fillPriceX18
        );

        marketOrder.clear();
    }

    struct FillOffchainOrders_Context {
        UD60x18 bidX18;
        UD60x18 askX18;
        uint256 cachedOffchainOrdersLength;
        OffchainOrder.Data offchainOrder;
        bytes32 structHash;
        bytes32 hash;
        address signer;
        bool isBuyOrder;
        UD60x18 indexPriceX18;
        UD60x18 fillPriceX18;
        bool isFillPriceValid;
    }

    /// @notice Fills pending, eligible offchain offchain orders targeting the given market id.
    /// @dev If a trading account id owner transfers their account to another address, all offchain orders will be
    /// considered cancelled.
    /// @param marketId The perp market id.
    /// @param offchainOrders The array of signed custom orders.
    /// @param priceData The price data of custom orders.
    function fillOffchainOrders(
        uint128 marketId,
        OffchainOrder.Data[] calldata offchainOrders,
        bytes calldata priceData
    )
        external
        onlyOffchainOrdersKeeper(marketId)
    {
        FillOffchainOrders_Context memory ctx;

        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, SettlementConfiguration.OFFCHAIN_ORDERS_CONFIGURATION_ID);
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);

        (ctx.bidX18, ctx.askX18) = settlementConfiguration.verifyOffchainPrice(priceData);

        // gas savings
        ctx.cachedOffchainOrdersLength = offchainOrders.length;

        for (uint256 i = 0; i < ctx.cachedOffchainOrdersLength; i++) {
            ctx.offchainOrder = offchainOrders[i];

            if (ctx.offchainOrder.sizeDelta == 0) {
                revert Errors.ZeroInput("offchainOrder.sizeDelta");
            }

            TradingAccount.Data storage tradingAccount =
                TradingAccount.loadExisting(ctx.offchainOrder.tradingAccountId);

            if (marketId != ctx.offchainOrder.marketId) {
                revert Errors.OrderMarketIdMismatch(marketId, ctx.offchainOrder.marketId);
            }

            // First we check if the nonce is valid, as a first measure to protect from replay attacks, according to
            // the offchain order's type (each type may have its own business logic).
            // e.g TP/SL must increase the nonce in order to prevent older limit orders from being filled.
            // NOTE: Since the nonce isn't always increased, we also need to store the typed data hash containing the
            // 256 bits salt value to fully prevent replay attacks.
            if (ctx.offchainOrder.nonce != tradingAccount.nonce) {
                revert Errors.InvalidSignedNonce(ctx.offchainOrder.tradingAccountId, ctx.offchainOrder.nonce);
            }

            ctx.structHash = keccak256(
                abi.encode(
                    Constants.SIGN_OFFCHAIN_ORDER_TYPEHASH,
                    ctx.offchainOrder.tradingAccountId,
                    ctx.offchainOrder.marketId,
                    SettlementConfiguration.OFFCHAIN_ORDERS_CONFIGURATION_ID,
                    ctx.offchainOrder.sizeDelta,
                    ctx.offchainOrder.targetPrice,
                    ctx.offchainOrder.shouldIncreaseNonce,
                    ctx.offchainOrder.salt
                )
            );
            ctx.hash = _hashTypedDataV4(ctx.structHash);

            // If the offchain order has already been filled, revert.
            // we store `ctx.hash`, and expect each order signed by the user to provide a unique salt so that filled
            // orders can't be replayed regardless of the account's nonce.
            if (tradingAccount.hasOffchainOrderBeenFilled[ctx.hash]) {
                revert Errors.OrderAlreadyFilled(ctx.offchainOrder.tradingAccountId, ctx.offchainOrder.salt);
            }

            // `ecrecover`s the order signer.
            ctx.signer = ECDSA.recover(ctx.hash, ctx.offchainOrder.v, ctx.offchainOrder.r, ctx.offchainOrder.s);

            // ensure the signer is the owner of the trading account, otherwise revert.
            // NOTE: If an account's owner transfers to another address, this will fail. Therefore, clients must
            // cancel all users offchain orders in that scenario.
            if (ctx.signer != tradingAccount.owner) {
                revert Errors.InvalidOrderSignature(ctx.signer, tradingAccount.owner);
            }

            // cache the order side
            ctx.isBuyOrder = ctx.offchainOrder.sizeDelta > 0;
            // if it's a buy order, we need to match against the ask price, if it's a sell order, we need to match
            // agaainst the bid price.
            ctx.indexPriceX18 = ctx.isBuyOrder ? ctx.askX18 : ctx.bidX18;

            // verify the provided price data against the verifier and ensure it's valid, then get the mark price
            // based on the returned index price.
            ctx.fillPriceX18 = perpMarket.getMarkPrice(sd59x18(ctx.offchainOrder.sizeDelta), ctx.indexPriceX18);

            // if the order increases the trading account's position (buy order), the fill price must be less than or
            // equal to the target price, if it decreases the trading account's position (sell order), the fill price
            // must be greater than or equal to the target price.
            ctx.isFillPriceValid = (ctx.isBuyOrder && ctx.offchainOrder.targetPrice <= ctx.fillPriceX18.intoUint256())
                || (!ctx.isBuyOrder && ctx.offchainOrder.targetPrice >= ctx.fillPriceX18.intoUint256());

            // we don't revert here because we want to continue filling other orders.
            if (!ctx.isFillPriceValid) {
                continue;
            }

            // account state updates start here

            // increase the trading account nonce if the order's flag is true.
            if (ctx.offchainOrder.shouldIncreaseNonce) {
                unchecked {
                    tradingAccount.nonce++;
                }
            }
            // mark the offchain order as filled.
            tradingAccount.hasOffchainOrderBeenFilled[ctx.hash] = true;

            // fill the offchain order.
            _fillOrder(
                ctx.offchainOrder.tradingAccountId,
                marketId,
                SettlementConfiguration.OFFCHAIN_ORDERS_CONFIGURATION_ID,
                sd59x18(ctx.offchainOrder.sizeDelta),
                ctx.fillPriceX18
            );
        }
    }

    struct FillOrderContext {
        address usdToken;
        uint128 marketId;
        uint128 tradingAccountId;
        bool isIncreasingPosition;
        UD60x18 orderFeeUsdX18;
        UD60x18 settlementFeeUsdX18;
        SD59x18 sizeDelta;
        SD59x18 pnl;
        SD59x18 fundingFeePerUnit;
        SD59x18 fundingRate;
        Position.Data newPosition;
        UD60x18 newOpenInterest;
        SD59x18 newSkew;
        UD60x18 requiredMarginUsdX18;
        bool shouldUseMaintenanceMargin;
    }

    /// @param tradingAccountId The trading account id.
    /// @param marketId The perp market id.
    /// @param settlementConfigurationId The perp market settlement configuration id.
    /// @param sizeDeltaX18 The size delta of the order normalized to 18 decimals.
    /// @param fillPriceX18 The fill price of the order normalized to 18 decimals.
    function _fillOrder(
        uint128 tradingAccountId,
        uint128 marketId,
        uint128 settlementConfigurationId,
        SD59x18 sizeDeltaX18,
        UD60x18 fillPriceX18
    )
        internal
        virtual
    {
        FillOrderContext memory ctx;

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, settlementConfigurationId);
        ctx.usdToken = globalConfiguration.usdToken;
        ctx.marketId = marketId;

        ctx.isIncreasingPosition =
            Position.isIncreasingPosition(tradingAccountId, marketId, sizeDeltaX18.intoInt256().toInt128());

        if (ctx.isIncreasingPosition) {
            globalConfiguration.checkMarketIsEnabled(ctx.marketId);
            settlementConfiguration.checkIsSettlementEnabled();
        }

        ctx.tradingAccountId = tradingAccountId;
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(ctx.tradingAccountId);

        PerpMarket.Data storage perpMarket = PerpMarket.load(ctx.marketId);
        perpMarket.checkTradeSize(sizeDeltaX18);

        ctx.fundingRate = perpMarket.getCurrentFundingRate();
        ctx.fundingFeePerUnit = perpMarket.getNextFundingFeePerUnit(ctx.fundingRate, fillPriceX18);

        perpMarket.updateFunding(ctx.fundingRate, ctx.fundingFeePerUnit);

        ctx.orderFeeUsdX18 = perpMarket.getOrderFeeUsd(sizeDeltaX18, fillPriceX18);
        ctx.settlementFeeUsdX18 = ud60x18(uint256(settlementConfiguration.fee));

        Position.Data storage oldPosition = Position.load(ctx.tradingAccountId, ctx.marketId);

        {
            (
                UD60x18 requiredInitialMarginUsdX18,
                UD60x18 requiredMaintenanceMarginUsdX18,
                SD59x18 accountTotalUnrealizedPnlUsdX18
            ) = tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(marketId, sizeDeltaX18);

            ctx.shouldUseMaintenanceMargin = !ctx.isIncreasingPosition && oldPosition.size != 0;

            ctx.requiredMarginUsdX18 =
                ctx.shouldUseMaintenanceMargin ? requiredMaintenanceMarginUsdX18 : requiredInitialMarginUsdX18;

            tradingAccount.validateMarginRequirement(
                ctx.requiredMarginUsdX18,
                tradingAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18),
                ctx.orderFeeUsdX18.add(ctx.settlementFeeUsdX18)
            );
        }

        ctx.pnl = oldPosition.getUnrealizedPnl(fillPriceX18).add(oldPosition.getAccruedFunding(ctx.fundingFeePerUnit))
            .add(unary(ctx.orderFeeUsdX18.add(ctx.settlementFeeUsdX18).intoSD59x18()));

        ctx.newPosition = Position.Data({
            size: sd59x18(oldPosition.size).add(sizeDeltaX18).intoInt256(),
            lastInteractionPrice: fillPriceX18.intoUint128(),
            lastInteractionFundingFeePerUnit: ctx.fundingFeePerUnit.intoInt256().toInt128()
        });

        (ctx.newOpenInterest, ctx.newSkew) =
            perpMarket.checkOpenInterestLimits(sizeDeltaX18, sd59x18(oldPosition.size), sd59x18(ctx.newPosition.size));
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

        if (ctx.pnl.lt(SD59x18_ZERO)) {
            UD60x18 marginToDeductUsdX18 = ctx.orderFeeUsdX18.add(ctx.settlementFeeUsdX18).gt(UD60x18_ZERO)
                ? ctx.pnl.abs().intoUD60x18().sub(ctx.orderFeeUsdX18.add(ctx.settlementFeeUsdX18))
                : ctx.pnl.abs().intoUD60x18();

            tradingAccount.deductAccountMargin({
                feeRecipients: FeeRecipients.Data({
                    marginCollateralRecipient: globalConfiguration.marginCollateralRecipient,
                    orderFeeRecipient: globalConfiguration.orderFeeRecipient,
                    settlementFeeRecipient: globalConfiguration.settlementFeeRecipient
                }),
                pnlUsdX18: marginToDeductUsdX18,
                orderFeeUsdX18: ctx.orderFeeUsdX18.gt(UD60x18_ZERO) ? ctx.orderFeeUsdX18 : UD60x18_ZERO,
                settlementFeeUsdX18: ctx.settlementFeeUsdX18
            });
        } else if (ctx.pnl.gt(SD59x18_ZERO)) {
            UD60x18 amountToIncrease = ctx.pnl.intoUD60x18();

            tradingAccount.deposit(ctx.usdToken, amountToIncrease);

            // NOTE: testnet only - will be updated once the Market Making Engine is finalized
            LimitedMintingERC20(ctx.usdToken).mint(address(this), amountToIncrease.intoUint256());
        }

        emit LogFillOrder(
            msg.sender,
            ctx.tradingAccountId,
            ctx.marketId,
            sizeDeltaX18.intoInt256(),
            fillPriceX18.intoUint256(),
            ctx.orderFeeUsdX18.intoUint256(),
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
