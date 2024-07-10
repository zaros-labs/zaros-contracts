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

    modifier onlySignedOrderKeeper(uint128 marketId, uint128 settlementConfigurationId) {
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, settlementConfigurationId);
        address keeper = settlementConfiguration.keeper;

        _requireIsKeeper(msg.sender, keeper);
        _;
    }

    /// @dev {SettlementBranch}  UUPS initializer.
    function initialize() external initializer {
        __EIP712_init("Zaros Perpetuals DEX: Settlement", "1");
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
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID);
        MarketOrder.Data storage marketOrder = MarketOrder.loadExisting(tradingAccountId);
        address keeper = settlementConfiguration.keeper;
        SD59x18 sizeDeltaX18 = sd59x18(marketOrder.sizeDelta);

        if (marketId != marketOrder.marketId) {
            revert Errors.OrderMarketIdMismatch(marketId, marketOrder.marketId);
        }

        _requireIsKeeper(msg.sender, keeper);

        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        (UD60x18 bidX18, UD60x18 askX18) = settlementConfiguration.verifyOffchainPrice(priceData);

        // TODO: encapsulate this logic in a function
        // cache the order side
        bool isBuyOrder = sizeDeltaX18.gt(SD59x18_ZERO);
        // if it's a buy order, we need to match against the ask price, if it's a sell order, we need to match
        // agaainst the bid price.
        UD60x18 indexPriceX18 = isBuyOrder ? askX18 : bidX18;

        // verify the provided price data against the verifier and ensure it's valid, then get the mark price
        // based on the returned index price.
        UD60x18 fillPriceX18 = perpMarket.getMarkPrice(sizeDeltaX18, indexPriceX18);

        _fillOrder(
            tradingAccountId,
            marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            sizeDeltaX18,
            fillPriceX18
        );

        marketOrder.clear();
    }

    struct FillSignedOrders_Context {
        UD60x18 bidX18;
        UD60x18 askX18;
        SignedOrder.Data signedOrder;
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes32 structHash;
        bytes32 hash;
        address signer;
        bool isBuyOrder;
        UD60x18 indexPriceX18;
        UD60x18 fillPriceX18;
        bool isFillPriceValid;
    }

    /// @param marketId The perp market id.
    /// @param settlementConfigurationId The perp market settlement configuration id being used.
    /// @param signedOrders The array of signed custom orders.
    /// @param priceData The price data of custom orders.
    function fillSignedOrders(
        uint128 marketId,
        uint128 settlementConfigurationId,
        SignedOrder.Data[] calldata signedOrders,
        bytes calldata priceData
    )
        external
        onlySignedOrderKeeper(marketId, settlementConfigurationId)
    {
        FillSignedOrders_Context memory ctx;

        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, SettlementConfiguration.SIGNED_ORDERS_CONFIGURATION_ID);
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);

        (ctx.bidX18, ctx.askX18) = settlementConfiguration.verifyOffchainPrice(priceData);

        for (uint256 i = 0; i < signedOrders.length; i++) {
            ctx.signedOrder = signedOrders[i];

            if (ctx.signedOrder.sizeDelta == 0) {
                revert Errors.ZeroInput("signedOrder.sizeDelta");
            }

            TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(ctx.signedOrder.tradingAccountId);

            if (marketId != ctx.signedOrder.marketId) {
                revert Errors.OrderMarketIdMismatch(marketId, ctx.signedOrder.marketId);
            }

            // check if the nonce is valid, in order to prevent replay attacks depending on the signed order type
            // e.g TP/SL must increase the nonce in order to prevent older limit orders from being filled.
            if (ctx.signedOrder.nonce != tradingAccount.nonce) {
                revert Errors.InvalidSignedNonce(ctx.signedOrder.tradingAccountId, ctx.signedOrder.nonce);
            }

            (ctx.v, ctx.r, ctx.s) = abi.decode(ctx.signedOrder.signature, (uint8, bytes32, bytes32));
            ctx.structHash = keccak256(
                abi.encode(
                    Constants.CREATE_SIGNED_ORDER_TYPEHASH,
                    ctx.signedOrder.tradingAccountId,
                    ctx.signedOrder.marketId,
                    settlementConfigurationId,
                    ctx.signedOrder.sizeDelta,
                    ctx.signedOrder.targetPrice,
                    ctx.signedOrder.shouldIncreaseNonce
                )
            );

            // EIP-712 typed data default hashing and signature verification
            ctx.hash = _hashTypedDataV4(ctx.structHash);
            ctx.signer = ECDSA.recover(ctx.hash, ctx.v, ctx.r, ctx.s);

            // ensure the signer is the owner of the trading account, otherwise revert.
            if (ctx.signer != tradingAccount.owner) {
                revert Errors.InvalidSignedOrderSignature(ctx.signer, tradingAccount.owner);
            }

            // cache the order side
            ctx.isBuyOrder = ctx.signedOrder.sizeDelta > 0;
            // if it's a buy order, we need to match against the ask price, if it's a sell order, we need to match
            // agaainst the bid price.
            ctx.indexPriceX18 = ctx.isBuyOrder ? ctx.askX18 : ctx.bidX18;

            // verify the provided price data against the verifier and ensure it's valid, then get the mark price
            // based on the returned index price.
            ctx.fillPriceX18 = perpMarket.getMarkPrice(sd59x18(ctx.signedOrder.sizeDelta), ctx.indexPriceX18);

            // if the order increases the trading account's position (buy order), the fill price must be less than or
            // equal to the target price, if it decreases the trading account's position (sell order), the fill price
            // must be greater than or equal to the target price.
            ctx.isFillPriceValid = (ctx.isBuyOrder && ctx.signedOrder.targetPrice <= ctx.fillPriceX18.intoUint256())
                || (!ctx.isBuyOrder && ctx.signedOrder.targetPrice >= ctx.fillPriceX18.intoUint256());

            // we don't revert here because we want to continue filling other orders.
            if (!ctx.isFillPriceValid) {
                continue;
            }

            // account state updates start here

            // increase the trading account nonce if the order's flag is true.
            if (ctx.signedOrder.shouldIncreaseNonce) {
                unchecked {
                    tradingAccount.nonce++;
                }
            }

            // fills the signed order.
            _fillOrder(
                ctx.signedOrder.tradingAccountId,
                marketId,
                settlementConfigurationId,
                sd59x18(ctx.signedOrder.sizeDelta),
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
