// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { LimitedMintingERC20 } from "testnet/LimitedMintingERC20.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { SignedOrder } from "../leaves/SignedOrder.sol";
import { MarketOrder } from "../leaves/MarketOrder.sol";
import { TradingAccount } from "../leaves/TradingAccount.sol";
import { FeeRecipients } from "../leaves/FeeRecipients.sol";
import { GlobalConfiguration } from "../leaves/GlobalConfiguration.sol";
import { PerpMarket } from "../leaves/PerpMarket.sol";
import { Position } from "../leaves/Position.sol";
import { SettlementConfiguration } from "../leaves/SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeERC20, IERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// Open Zeppelin Upgradeable dependencies
import { EIP712Upgradeable } from "@openzeppelin-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD60x18_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

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

        if (marketId != marketOrder.marketId) {
            /// @notice Thrown when the selected market id mismatch with marder order market id
            revert Errors.MarketOrderMarketIdMismatch(marketId, marketOrder.marketId);
        }

        _requireIsKeeper(msg.sender, keeper);

        _fillOrder(
            tradingAccountId,
            marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            marketOrder.sizeDelta,
            priceData
        );

        marketOrder.clear();
    }

    struct FillSignedOrders_Context {
        SignedOrder.Data signedOrder;
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes32 structHash;
        bytes32 hash;
        address signer;
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

        for (uint256 i = 0; i < signedOrders.length; i++) {
            ctx.signedOrder = signedOrders[i];
            TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(ctx.signedOrder.tradingAccountId);

            (ctx.v, ctx.r, ctx.s) = abi.decode(ctx.signedOrder.signature, (uint8, bytes32, bytes32));
            ctx.structHash = keccak256(
                abi.encode(
                    Constants.CREATE_CUSTOM_ORDER_TYPEHASH,
                    ctx.signedOrder.tradingAccountId,
                    marketId,
                    settlementConfigurationId,
                    ctx.signedOrder.sizeDelta,
                    ctx.signedOrder.targetPrice
                )
            );

            ctx.hash = _hashTypedDataV4(ctx.structHash);
            ctx.signer = ECDSA.recover(ctx.hash, ctx.v, ctx.r, ctx.s);

            if (ctx.signer != tradingAccount.owner) {
                revert Errors.InvalidSignedOrderSignature(ctx.signer, tradingAccount.owner);
            }

            _fillOrder(
                ctx.signedOrder.tradingAccountId,
                marketId,
                settlementConfigurationId,
                ctx.signedOrder.sizeDelta,
                priceData
            );
        }
    }

    struct FillOrderContext {
        address usdToken;
        uint128 marketId;
        uint128 tradingAccountId;
        UD60x18 orderFeeUsdX18;
        UD60x18 settlementFeeUsdX18;
        SD59x18 sizeDelta;
        UD60x18 fillPrice;
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

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        SettlementConfiguration.Data storage settlementConfiguration =
            SettlementConfiguration.load(marketId, settlementConfigurationId);
        ctx.usdToken = globalConfiguration.usdToken;
        ctx.marketId = marketId;

        {
            bool isIncreasingPosition = Position.isIncreasingPosition(tradingAccountId, marketId, sizeDelta);

            if (isIncreasingPosition) {
                globalConfiguration.checkMarketIsEnabled(ctx.marketId);
                settlementConfiguration.checkIsSettlementEnabled();
            }
        }

        ctx.tradingAccountId = tradingAccountId;
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(ctx.tradingAccountId);

        PerpMarket.Data storage perpMarket = PerpMarket.load(ctx.marketId);
        ctx.sizeDelta = sd59x18(sizeDelta);
        perpMarket.checkTradeSize(ctx.sizeDelta);

        Position.Data storage oldPosition = Position.load(ctx.tradingAccountId, ctx.marketId);

        ctx.fillPrice = perpMarket.getMarkPrice(
            ctx.sizeDelta, settlementConfiguration.verifyOffchainPrice(priceData, ctx.sizeDelta.gt(SD_ZERO))
        );

        ctx.fundingRate = perpMarket.getCurrentFundingRate();
        ctx.fundingFeePerUnit = perpMarket.getNextFundingFeePerUnit(ctx.fundingRate, ctx.fillPrice);

        perpMarket.updateFunding(ctx.fundingRate, ctx.fundingFeePerUnit);

        ctx.orderFeeUsdX18 = perpMarket.getOrderFeeUsd(ctx.sizeDelta, ctx.fillPrice);
        ctx.settlementFeeUsdX18 = ud60x18(uint256(settlementConfiguration.fee));

        {
            (
                UD60x18 requiredInitialMarginUsdX18,
                UD60x18 requiredMaintenanceMarginUsdX18,
                SD59x18 accountTotalUnrealizedPnlUsdX18
            ) = tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(marketId, ctx.sizeDelta);

            ctx.shouldUseMaintenanceMargin =
                !Position.isIncreasingPosition(tradingAccountId, marketId, sizeDelta) && oldPosition.size != 0;

            ctx.requiredMarginUsdX18 =
                ctx.shouldUseMaintenanceMargin ? requiredMaintenanceMarginUsdX18 : requiredInitialMarginUsdX18;

            tradingAccount.validateMarginRequirement(
                ctx.requiredMarginUsdX18,
                tradingAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18),
                ctx.orderFeeUsdX18.add(ctx.settlementFeeUsdX18)
            );
        }

        ctx.pnl = oldPosition.getUnrealizedPnl(ctx.fillPrice).add(
            oldPosition.getAccruedFunding(ctx.fundingFeePerUnit)
        ).add(unary(ctx.orderFeeUsdX18.add(ctx.settlementFeeUsdX18).intoSD59x18()));

        ctx.newPosition = Position.Data({
            size: sd59x18(oldPosition.size).add(ctx.sizeDelta).intoInt256(),
            lastInteractionPrice: ctx.fillPrice.intoUint128(),
            lastInteractionFundingFeePerUnit: ctx.fundingFeePerUnit.intoInt256().toInt128()
        });

        (ctx.newOpenInterest, ctx.newSkew) = perpMarket.checkOpenInterestLimits(
            ctx.sizeDelta, sd59x18(oldPosition.size), sd59x18(ctx.newPosition.size)
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
