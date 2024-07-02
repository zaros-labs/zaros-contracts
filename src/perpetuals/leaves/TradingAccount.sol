// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { FeeRecipients } from "./FeeRecipients.sol";
import { GlobalConfiguration } from "./GlobalConfiguration.sol";
import { MarginCollateralConfiguration } from "./MarginCollateralConfiguration.sol";
import { PerpMarket } from "./PerpMarket.sol";
import { Position } from "./Position.sol";
import { SettlementConfiguration } from "./SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { SafeERC20, IERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

/// @title The TradingAccount namespace.
library TradingAccount {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for *;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using MarginCollateralConfiguration for MarginCollateralConfiguration.Data;
    using SettlementConfiguration for SettlementConfiguration.Data;

    /// @notice ERC7201 storage location.
    bytes32 internal constant TRADING_ACCOUNT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.perpetuals.TradingAccount")) - 1)) & ~bytes32(uint256(0xff));

    /// @notice {TradingAccount} namespace storage structure.
    /// @param id The trading account id.
    /// @param owner The trading account owner.
    /// @param marginCollateralBalanceX18 The trading account margin collateral enumerable map.
    /// @param activeMarketsIds The trading account active markets ids enumerable set.
    struct Data {
        uint128 id;
        address owner;
        EnumerableMap.AddressToUintMap marginCollateralBalanceX18;
        EnumerableSet.UintSet activeMarketsIds;
    }

    /// @notice Loads a {TradingAccount}.
    /// @param tradingAccountId The trading account id.
    /// @return tradingAccount The loaded trading account storage pointer.
    function load(uint128 tradingAccountId) internal pure returns (Data storage tradingAccount) {
        bytes32 slot = keccak256(abi.encode(TRADING_ACCOUNT_LOCATION, tradingAccountId));
        assembly {
            tradingAccount.slot := slot
        }
    }

    /// @notice Checks whether the given trading account exists.
    /// @param tradingAccountId The trading account id.
    /// @return tradingAccount if the trading account exists, its storage pointer is returned.
    function loadExisting(uint128 tradingAccountId) internal view returns (Data storage tradingAccount) {
        tradingAccount = load(tradingAccountId);
        if (tradingAccount.owner == address(0)) {
            revert Errors.AccountNotFound(tradingAccountId, msg.sender);
        }
    }

    /// @notice Loads an existing trading account and checks if the `msg.sender` is authorized.
    /// @param tradingAccountId The trading account id.
    /// @return tradingAccount The loaded trading account storage pointer.
    function loadExistingAccountAndVerifySender(uint128 tradingAccountId)
        internal
        view
        returns (Data storage tradingAccount)
    {
        tradingAccount = loadExisting(tradingAccountId);
        verifySender(tradingAccountId);
    }

    /// @notice Validates if the trading account is under the configured positions limit.
    /// @dev This function must be called when the trading account is going to open a new position. If called in a
    /// context
    /// of an already active market, the check may be misleading.
    function validatePositionsLimit(Data storage self) internal view {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        uint256 maxPositionsPerAccount = globalConfiguration.maxPositionsPerAccount;
        uint256 activePositionsLength = self.activeMarketsIds.length();

        if (activePositionsLength >= maxPositionsPerAccount) {
            revert Errors.MaxPositionsPerAccountReached(self.id, activePositionsLength, maxPositionsPerAccount);
        }
    }

    /// @notice Validates if the given account will still meet margin requirements after a given operation.
    /// @dev Reverts if the new account margin state is invalid (requiredMargin >= marginBalance).
    /// @dev Must be called whenever a position is updated or the margin balance is reduced.
    /// @param self The trading account storage pointer.
    /// @param requiredMarginUsdX18 The minimum required margin balance for the account
    /// @param marginBalanceUsdX18 The account's margin balance.
    /// @param totalFeesUsdX18 The total fees to be charged to the account in the current context.
    function validateMarginRequirement(
        Data storage self,
        UD60x18 requiredMarginUsdX18,
        SD59x18 marginBalanceUsdX18,
        UD60x18 totalFeesUsdX18
    )
        internal
        view
    {
        if (requiredMarginUsdX18.add(totalFeesUsdX18).intoSD59x18().gt(marginBalanceUsdX18)) {
            revert Errors.InsufficientMargin(
                self.id,
                marginBalanceUsdX18.intoInt256(),
                requiredMarginUsdX18.intoUint256(),
                totalFeesUsdX18.intoUint256()
            );
        }
    }

    /// @notice Returns the amount of the given margin collateral type.
    /// @param self The trading account storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @return marginCollateralBalanceX18 The margin collateral balance for the given collateral type.
    function getMarginCollateralBalance(Data storage self, address collateralType) internal view returns (UD60x18) {
        (, uint256 marginCollateralBalanceX18) = self.marginCollateralBalanceX18.tryGet(collateralType);

        return ud60x18(marginCollateralBalanceX18);
    }

    /// @notice Returns the equity usd value of all margin collateral in the account.
    /// @param self The trading account storage pointer.
    /// @return equityUsdX18 The total margin collateral value.
    function getEquityUsd(
        Data storage self,
        SD59x18 activePositionsUnrealizedPnlUsdX18
    )
        internal
        view
        returns (SD59x18 equityUsdX18)
    {
        for (uint256 i; i < self.marginCollateralBalanceX18.length(); i++) {
            (address collateralType, uint256 balanceX18) = self.marginCollateralBalanceX18.at(i);
            MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
                MarginCollateralConfiguration.load(collateralType);
            UD60x18 balanceUsdX18 = marginCollateralConfiguration.getPrice().mul(ud60x18(balanceX18));

            equityUsdX18 = equityUsdX18.add(balanceUsdX18.intoSD59x18());
        }

        equityUsdX18 = equityUsdX18.add(activePositionsUnrealizedPnlUsdX18);
    }

    /// @notice Returns the margin balance of the account in usd.
    /// @dev The margin balance takes uPnL and each collateral type's LTV into account.
    /// @param self The trading account storage pointer.
    /// @param activePositionsUnrealizedPnlUsdX18 The total unrealized PnL of the account's active positions.
    function getMarginBalanceUsd(
        Data storage self,
        SD59x18 activePositionsUnrealizedPnlUsdX18
    )
        internal
        view
        returns (SD59x18 marginBalanceUsdX18)
    {
        for (uint256 i; i < self.marginCollateralBalanceX18.length(); i++) {
            (address collateralType, uint256 balance) = self.marginCollateralBalanceX18.at(i);
            MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
                MarginCollateralConfiguration.load(collateralType);

            UD60x18 adjustedBalanceUsdX18 = marginCollateralConfiguration.getPrice().mul(ud60x18(balance)).mul(
                ud60x18(marginCollateralConfiguration.loanToValue)
            );

            marginBalanceUsdX18 = marginBalanceUsdX18.add(adjustedBalanceUsdX18.intoSD59x18());
        }

        marginBalanceUsdX18 = marginBalanceUsdX18.add(activePositionsUnrealizedPnlUsdX18);
    }

    /// @notice Returns the account's margin requirements and total unrealized PnL in USD.
    /// @param self The trading account storage pointer.
    /// @param targetMarketId The market id to simulate the margin requirements.
    /// @param sizeDeltaX18 The size delta to simulate the margin requirements.
    /// @return requiredInitialMarginUsdX18 The total initial margin required by the account.
    /// @return requiredMaintenanceMarginUsdX18 The total maintenance margin required by the account.
    /// @return accountTotalUnrealizedPnlUsdX18 The total unrealized PnL of the account.
    function getAccountMarginRequirementUsdAndUnrealizedPnlUsd(
        Data storage self,
        uint128 targetMarketId,
        SD59x18 sizeDeltaX18
    )
        internal
        view
        returns (
            UD60x18 requiredInitialMarginUsdX18,
            UD60x18 requiredMaintenanceMarginUsdX18,
            SD59x18 accountTotalUnrealizedPnlUsdX18
        )
    {
        if (targetMarketId != 0) {
            PerpMarket.Data storage perpMarket = PerpMarket.load(targetMarketId);
            Position.Data storage position = Position.load(self.id, targetMarketId);

            UD60x18 markPrice = perpMarket.getMarkPrice(sizeDeltaX18, perpMarket.getIndexPrice());
            SD59x18 fundingFeePerUnit =
                perpMarket.getNextFundingFeePerUnit(perpMarket.getCurrentFundingRate(), markPrice);

            // when dealing with the market id being settled, we simulate the new position size to get the new
            // margin requirements.
            UD60x18 notionalValueX18 = sd59x18(position.size).add(sizeDeltaX18).abs().intoUD60x18().mul(markPrice);

            (UD60x18 positionInitialMarginUsdX18, UD60x18 positionMaintenanceMarginUsdX18) = Position
                .getMarginRequirement(
                notionalValueX18,
                ud60x18(perpMarket.configuration.initialMarginRateX18),
                ud60x18(perpMarket.configuration.maintenanceMarginRateX18)
            );
            SD59x18 positionUnrealizedPnl =
                position.getUnrealizedPnl(markPrice).add(position.getAccruedFunding(fundingFeePerUnit));

            requiredInitialMarginUsdX18 = requiredInitialMarginUsdX18.add(positionInitialMarginUsdX18);
            requiredMaintenanceMarginUsdX18 = requiredMaintenanceMarginUsdX18.add(positionMaintenanceMarginUsdX18);
            accountTotalUnrealizedPnlUsdX18 = accountTotalUnrealizedPnlUsdX18.add(positionUnrealizedPnl);
        }

        for (uint256 i; i < self.activeMarketsIds.length(); i++) {
            uint128 marketId = self.activeMarketsIds.at(i).toUint128();

            if (marketId == targetMarketId) {
                continue;
            }

            PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
            Position.Data storage position = Position.load(self.id, marketId);

            UD60x18 markPrice = perpMarket.getMarkPrice(sd59x18(-position.size), perpMarket.getIndexPrice());
            SD59x18 fundingFeePerUnit =
                perpMarket.getNextFundingFeePerUnit(perpMarket.getCurrentFundingRate(), markPrice);

            UD60x18 notionalValueX18 = position.getNotionalValue(markPrice);

            (UD60x18 positionInitialMarginUsdX18, UD60x18 positionMaintenanceMarginUsdX18) = Position
                .getMarginRequirement(
                notionalValueX18,
                ud60x18(perpMarket.configuration.initialMarginRateX18),
                ud60x18(perpMarket.configuration.maintenanceMarginRateX18)
            );
            SD59x18 positionUnrealizedPnl =
                position.getUnrealizedPnl(markPrice).add(position.getAccruedFunding(fundingFeePerUnit));

            requiredInitialMarginUsdX18 = requiredInitialMarginUsdX18.add(positionInitialMarginUsdX18);
            requiredMaintenanceMarginUsdX18 = requiredMaintenanceMarginUsdX18.add(positionMaintenanceMarginUsdX18);
            accountTotalUnrealizedPnlUsdX18 = accountTotalUnrealizedPnlUsdX18.add(positionUnrealizedPnl);
        }
    }

    /// @notice Returns the account's unrealized PnL in USD.
    /// @param self The trading account storage pointer.
    /// @return totalUnrealizedPnlUsdX18 The total unrealized PnL of the account.
    function getAccountUnrealizedPnlUsd(Data storage self) internal view returns (SD59x18 totalUnrealizedPnlUsdX18) {
        for (uint256 i; i < self.activeMarketsIds.length(); i++) {
            uint128 marketId = self.activeMarketsIds.at(i).toUint128();
            PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
            Position.Data storage position = Position.load(self.id, marketId);

            UD60x18 indexPriceX18 = perpMarket.getIndexPrice();
            UD60x18 markPriceX18 = perpMarket.getMarkPrice(unary(sd59x18(position.size)), indexPriceX18);

            SD59x18 fundingRateX18 = perpMarket.getCurrentFundingRate();
            SD59x18 fundingFeePerUnitX18 = perpMarket.getNextFundingFeePerUnit(fundingRateX18, markPriceX18);

            SD59x18 accruedFundingUsdX18 = position.getAccruedFunding(fundingFeePerUnitX18);
            SD59x18 unrealizedPnlUsdX18 = position.getUnrealizedPnl(markPriceX18);

            totalUnrealizedPnlUsdX18 = totalUnrealizedPnlUsdX18.add(unrealizedPnlUsdX18).add(accruedFundingUsdX18);
        }
    }

    /// @notice Verifies if the `msg.sender` is authorized to perform actions on the given trading account id.
    /// @param tradingAccountId The trading account id.
    function verifySender(uint128 tradingAccountId) internal view {
        Data storage self = load(tradingAccountId);
        if (self.owner != msg.sender) {
            revert Errors.AccountPermissionDenied(tradingAccountId, msg.sender);
        }
    }

    /// @notice Checks if the account is liquidatable.
    /// @param requiredMaintenanceMarginUsdX18 The required maintenance margin in USD.
    /// @param marginBalanceUsdX18 The account's margin balance in USD.
    function isLiquidatable(
        UD60x18 requiredMaintenanceMarginUsdX18,
        SD59x18 marginBalanceUsdX18
    )
        internal
        pure
        returns (bool)
    {
        return requiredMaintenanceMarginUsdX18.intoSD59x18().gt(marginBalanceUsdX18);
    }

    /// @notice Checks if the account has an active position in the given market.
    /// @param self The trading account storage pointer.
    /// @param marketId The market id.
    function isMarketWithActivePosition(Data storage self, uint128 marketId) internal view returns (bool) {
        return self.activeMarketsIds.contains(marketId);
    }

    /// @notice Creates a new trading account.
    /// @param tradingAccountId The trading account id.
    /// @param owner The trading account owner.
    /// @return tradingAccount The created trading account storage pointer.
    function create(uint128 tradingAccountId, address owner) internal returns (Data storage tradingAccount) {
        tradingAccount = load(tradingAccountId);
        tradingAccount.id = tradingAccountId;
        tradingAccount.owner = owner;
    }

    /// @notice Deposits the given collateral type into the trading account.
    /// @param self The trading account storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @param amountX18 The amount of margin collateral to be added.
    function deposit(Data storage self, address collateralType, UD60x18 amountX18) internal {
        EnumerableMap.AddressToUintMap storage marginCollateralBalanceX18 = self.marginCollateralBalanceX18;
        MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);

        UD60x18 newMarginCollateralBalance = getMarginCollateralBalance(self, collateralType).add(amountX18);

        marginCollateralBalanceX18.set(collateralType, newMarginCollateralBalance.intoUint256());
        marginCollateralConfiguration.totalDeposited =
            ud60x18(marginCollateralConfiguration.totalDeposited).add(amountX18).intoUint256();
    }

    /// @notice Withdraws the given collateral type from the trading account.
    /// @param self The trading account storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @param amountX18 The amount of margin collateral to be removed.
    function withdraw(Data storage self, address collateralType, UD60x18 amountX18) internal {
        EnumerableMap.AddressToUintMap storage marginCollateralBalanceX18 = self.marginCollateralBalanceX18;
        UD60x18 newMarginCollateralBalance = getMarginCollateralBalance(self, collateralType).sub(amountX18);

        if (newMarginCollateralBalance.isZero()) {
            marginCollateralBalanceX18.remove(collateralType);
        } else {
            marginCollateralBalanceX18.set(collateralType, newMarginCollateralBalance.intoUint256());
        }
    }

    /// @notice Withdraws the given amount of margin collateral in USD from the trading account.
    /// @param self The trading account storage pointer.
    /// @param collateralType The address of the collateral type.
    /// @param marginCollateralPriceUsdX18 The price of the margin collateral in USD.
    /// @param amountUsdX18 The amount of margin collateral to be withdrawn in USD.
    /// @param recipient The address of the recipient.
    /// @return withdrawnMarginUsdX18 The amount of margin collateral withdrawn in USD.
    /// @return isMissingMargin Whether the account is missing margin to meet all requirements or not.
    function withdrawMarginUsd(
        Data storage self,
        address collateralType,
        UD60x18 marginCollateralPriceUsdX18,
        UD60x18 amountUsdX18,
        address recipient
    )
        internal
        returns (UD60x18 withdrawnMarginUsdX18, bool isMissingMargin)
    {
        MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);

        UD60x18 marginCollateralBalanceX18 = getMarginCollateralBalance(self, collateralType);
        UD60x18 requiredMarginInCollateralX18 = amountUsdX18.div(marginCollateralPriceUsdX18);
        uint256 amountToTransfer;

        if (marginCollateralBalanceX18.gte(requiredMarginInCollateralX18)) {
            withdraw(self, collateralType, requiredMarginInCollateralX18);
            amountToTransfer =
                marginCollateralConfiguration.convertUd60x18ToTokenAmount(requiredMarginInCollateralX18);

            IERC20(collateralType).safeTransfer(recipient, amountToTransfer);

            withdrawnMarginUsdX18 = amountUsdX18;
            isMissingMargin = false;

            return (withdrawnMarginUsdX18, isMissingMargin);
        } else {
            UD60x18 marginToWithdrawUsdX18 = marginCollateralPriceUsdX18.mul(marginCollateralBalanceX18);
            withdraw(self, collateralType, marginCollateralBalanceX18);
            amountToTransfer = marginCollateralConfiguration.convertUd60x18ToTokenAmount(marginCollateralBalanceX18);

            IERC20(collateralType).safeTransfer(recipient, amountToTransfer);

            withdrawnMarginUsdX18 = marginToWithdrawUsdX18;
            isMissingMargin = true;

            return (withdrawnMarginUsdX18, isMissingMargin);
        }
    }

    struct DeductAccountMarginContext {
        UD60x18 marginCollateralBalanceX18;
        UD60x18 marginCollateralPriceUsdX18;
        UD60x18 settlementFeeDeductedUsdX18;
        UD60x18 withdrawnMarginUsdX18;
        bool isMissingMargin;
        UD60x18 orderFeeDeductedUsdX18;
        UD60x18 pnlDeductedUsdX18;
    }

    /// @notice Deducts the account's margin to pay for the settlement fee, order fee, and realize the pnl.
    /// @param self The trading account storage pointer.
    /// @param feeRecipients The fee recipients.
    /// @param pnlUsdX18 The total unrealized PnL of the account.
    /// @param settlementFeeUsdX18 The total settlement fee to be deducted from the account.
    /// @param orderFeeUsdX18 The total order fee to be deducted from the account.
    /// @return marginDeductedUsdX18 The total margin deducted from the account.
    function deductAccountMargin(
        Data storage self,
        FeeRecipients.Data memory feeRecipients,
        UD60x18 pnlUsdX18,
        UD60x18 settlementFeeUsdX18,
        UD60x18 orderFeeUsdX18
    )
        internal
        returns (UD60x18 marginDeductedUsdX18)
    {
        DeductAccountMarginContext memory ctx;

        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        for (uint256 i; i < globalConfiguration.collateralLiquidationPriority.length(); i++) {
            address collateralType = globalConfiguration.collateralLiquidationPriority.at(i);
            MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
                MarginCollateralConfiguration.load(collateralType);

            ctx.marginCollateralBalanceX18 = getMarginCollateralBalance(self, collateralType);
            if (ctx.marginCollateralBalanceX18.isZero()) continue;

            ctx.marginCollateralPriceUsdX18 = marginCollateralConfiguration.getPrice();

            if (settlementFeeUsdX18.gt(UD_ZERO) && ctx.settlementFeeDeductedUsdX18.lt(settlementFeeUsdX18)) {
                (ctx.withdrawnMarginUsdX18, ctx.isMissingMargin) = withdrawMarginUsd(
                    self,
                    collateralType,
                    ctx.marginCollateralPriceUsdX18,
                    settlementFeeUsdX18.sub(ctx.settlementFeeDeductedUsdX18),
                    feeRecipients.settlementFeeRecipient
                );
                ctx.settlementFeeDeductedUsdX18 = ctx.settlementFeeDeductedUsdX18.add(ctx.withdrawnMarginUsdX18);

                if (ctx.isMissingMargin) continue;
            }

            marginDeductedUsdX18 = marginDeductedUsdX18.add(ctx.settlementFeeDeductedUsdX18);

            if (orderFeeUsdX18.gt(UD_ZERO) && ctx.orderFeeDeductedUsdX18.lt(orderFeeUsdX18)) {
                (ctx.withdrawnMarginUsdX18, ctx.isMissingMargin) = withdrawMarginUsd(
                    self,
                    collateralType,
                    ctx.marginCollateralPriceUsdX18,
                    orderFeeUsdX18.sub(ctx.orderFeeDeductedUsdX18),
                    feeRecipients.orderFeeRecipient
                );
                ctx.orderFeeDeductedUsdX18 = ctx.orderFeeDeductedUsdX18.add(ctx.withdrawnMarginUsdX18);

                if (ctx.isMissingMargin) continue;
            }

            marginDeductedUsdX18 = marginDeductedUsdX18.add(ctx.orderFeeDeductedUsdX18);

            if (pnlUsdX18.gt(UD_ZERO) && ctx.pnlDeductedUsdX18.lt(pnlUsdX18)) {
                (ctx.withdrawnMarginUsdX18, ctx.isMissingMargin) = withdrawMarginUsd(
                    self,
                    collateralType,
                    ctx.marginCollateralPriceUsdX18,
                    pnlUsdX18.sub(ctx.pnlDeductedUsdX18),
                    feeRecipients.marginCollateralRecipient
                );
                ctx.pnlDeductedUsdX18 = ctx.pnlDeductedUsdX18.add(ctx.withdrawnMarginUsdX18);

                if (!ctx.isMissingMargin) {
                    marginDeductedUsdX18 = marginDeductedUsdX18.add(ctx.pnlDeductedUsdX18);
                    break;
                }
            }
            marginDeductedUsdX18 = marginDeductedUsdX18.add(ctx.pnlDeductedUsdX18);
        }
    }

    /// @notice Updates the account's active markets ids based on the position's state transition.
    /// @param self The trading account storage pointer.
    /// @param marketId The perps market id.
    /// @param oldPositionSize The old position size.
    /// @param newPositionSize The new position size.
    function updateActiveMarkets(
        Data storage self,
        uint128 marketId,
        SD59x18 oldPositionSize,
        SD59x18 newPositionSize
    )
        internal
    {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();

        if (oldPositionSize.isZero() && !newPositionSize.isZero()) {
            if (!globalConfiguration.accountsIdsWithActivePositions.contains(self.id)) {
                globalConfiguration.accountsIdsWithActivePositions.add(self.id);
            }
            self.activeMarketsIds.add(marketId);
        } else if (oldPositionSize.neq(SD_ZERO) && newPositionSize.eq(SD_ZERO)) {
            self.activeMarketsIds.remove(marketId);

            if (self.activeMarketsIds.length() == 0) {
                globalConfiguration.accountsIdsWithActivePositions.remove(self.id);
            }
        }
    }
}
