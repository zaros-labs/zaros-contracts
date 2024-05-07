// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { IAccountNFT } from "@zaros/account-nft/interfaces/IAccountNFT.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { ITradingAccountBranch } from "../interfaces/ITradingAccountBranch.sol";
import { TradingAccount } from "../leaves/TradingAccount.sol";
import { GlobalConfiguration } from "../leaves/GlobalConfiguration.sol";
import { PerpMarket } from "../leaves/PerpMarket.sol";
import { Position } from "../leaves/Position.sol";
import { MarginCollateralConfiguration } from "../leaves/MarginCollateralConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

import { console } from "forge-std/console.sol";

/// @notice See {ITradingAccountBranch}.
contract TradingAccountBranch is ITradingAccountBranch {
    using EnumerableSet for *;
    using TradingAccount for TradingAccount.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using MarginCollateralConfiguration for MarginCollateralConfiguration.Data;

    /// @inheritdoc ITradingAccountBranch
    function getTradingAccountToken() public view override returns (address) {
        return GlobalConfiguration.load().tradingAccountToken;
    }

    /// @inheritdoc ITradingAccountBranch
    function getAccountMarginCollateralBalance(
        uint128 accountId,
        address collateralType
    )
        external
        view
        override
        returns (UD60x18)
    {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(accountId);
        UD60x18 marginCollateralBalanceX18 = tradingAccount.getMarginCollateralBalance(collateralType);

        return marginCollateralBalanceX18;
    }

    /// @inheritdoc ITradingAccountBranch
    function getAccountEquityUsd(uint128 accountId) external view override returns (SD59x18) {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(accountId);
        SD59x18 activePositionsUnrealizedPnlUsdX18 = tradingAccount.getAccountUnrealizedPnlUsd();

        return tradingAccount.getEquityUsd(activePositionsUnrealizedPnlUsdX18);
    }

    /// @inheritdoc ITradingAccountBranch
    function getAccountMarginBreakdown(uint128 accountId)
        external
        view
        override
        returns (
            SD59x18 marginBalanceUsdX18,
            UD60x18 initialMarginUsdX18,
            UD60x18 maintenanceMarginUsdX18,
            SD59x18 availableMarginUsdX18
        )
    {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(accountId);
        SD59x18 activePositionsUnrealizedPnlUsdX18 = tradingAccount.getAccountUnrealizedPnlUsd();

        console.log("from trading account branch: ");
        console.log(activePositionsUnrealizedPnlUsdX18.lt(SD_ZERO));
        console.log(activePositionsUnrealizedPnlUsdX18.abs().intoUD60x18().intoUint256());

        marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(activePositionsUnrealizedPnlUsdX18);

        console.log(marginBalanceUsdX18.abs().intoUD60x18().intoUint256());

        for (uint256 i = 0; i < tradingAccount.activeMarketsIds.length(); i++) {
            uint128 marketId = tradingAccount.activeMarketsIds.at(i).toUint128();

            PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
            Position.Data storage position = Position.load(accountId, marketId);

            UD60x18 indexPrice = perpMarket.getIndexPrice();
            UD60x18 markPrice = perpMarket.getMarkPrice(unary(sd59x18(position.size)), indexPrice);

            UD60x18 notionalValueX18 = position.getNotionalValue(markPrice);
            (UD60x18 positionInitialMarginUsdX18, UD60x18 positionMaintenanceMarginUsdX18) = Position
                .getMarginRequirement(
                notionalValueX18,
                ud60x18(perpMarket.configuration.initialMarginRateX18),
                ud60x18(perpMarket.configuration.maintenanceMarginRateX18)
            );

            initialMarginUsdX18 = initialMarginUsdX18.add(positionInitialMarginUsdX18);
            maintenanceMarginUsdX18 = maintenanceMarginUsdX18.add(positionMaintenanceMarginUsdX18);
        }

        availableMarginUsdX18 =
            marginBalanceUsdX18.sub((initialMarginUsdX18.add(maintenanceMarginUsdX18)).intoSD59x18());
    }

    /// @inheritdoc ITradingAccountBranch
    function getAccountTotalUnrealizedPnl(uint128 accountId)
        external
        view
        returns (SD59x18 accountTotalUnrealizedPnlUsdX18)
    {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(accountId);
        accountTotalUnrealizedPnlUsdX18 = tradingAccount.getAccountUnrealizedPnlUsd();
    }

    function getAccountLeverage(uint128 accountId) external view returns (UD60x18) {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(accountId);

        SD59x18 marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(tradingAccount.getAccountUnrealizedPnlUsd());
        UD60x18 totalPositionsNotionalValue;

        for (uint256 i = 0; i < tradingAccount.activeMarketsIds.length(); i++) {
            uint128 marketId = tradingAccount.activeMarketsIds.at(i).toUint128();

            PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
            Position.Data storage position = Position.load(accountId, marketId);

            UD60x18 indexPrice = perpMarket.getIndexPrice();
            UD60x18 markPrice = perpMarket.getMarkPrice(unary(sd59x18(position.size)), indexPrice);

            UD60x18 positionNotionalValueX18 = position.getNotionalValue(markPrice);
            totalPositionsNotionalValue = totalPositionsNotionalValue.add(positionNotionalValueX18);
        }

        return marginBalanceUsdX18.isZero()
            ? marginBalanceUsdX18.intoUD60x18()
            : totalPositionsNotionalValue.intoSD59x18().div(marginBalanceUsdX18).intoUD60x18();
    }

    /// @inheritdoc ITradingAccountBranch
    function getPositionState(
        uint128 accountId,
        uint128 marketId
    )
        external
        view
        override
        returns (Position.State memory positionState)
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        Position.Data storage position = Position.load(accountId, marketId);

        UD60x18 markPriceX18 = perpMarket.getMarkPrice(unary(sd59x18(position.size)), perpMarket.getIndexPrice());
        SD59x18 fundingFeePerUnit =
            perpMarket.getNextFundingFeePerUnit(perpMarket.getCurrentFundingRate(), markPriceX18);

        positionState = position.getState(
            ud60x18(perpMarket.configuration.initialMarginRateX18),
            ud60x18(perpMarket.configuration.maintenanceMarginRateX18),
            markPriceX18,
            fundingFeePerUnit
        );
    }

    /// @inheritdoc ITradingAccountBranch
    function createTradingAccount() public virtual override returns (uint128) {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        uint128 accountId = ++globalConfiguration.nextAccountId;
        IAccountNFT tradingAccountToken = IAccountNFT(globalConfiguration.tradingAccountToken);
        TradingAccount.create(accountId, msg.sender);

        tradingAccountToken.mint(msg.sender, accountId);

        emit LogCreateTradingAccount(accountId, msg.sender);
        return accountId;
    }

    /// @inheritdoc ITradingAccountBranch
    function createTradingAccountAndMulticall(bytes[] calldata data)
        external
        payable
        virtual
        override
        returns (bytes[] memory results)
    {
        uint128 accountId = createTradingAccount();

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            bytes memory dataWithAccountId = abi.encodePacked(data[i][0:4], abi.encode(accountId), data[i][4:]);
            (bool success, bytes memory result) = address(this).delegatecall(dataWithAccountId);

            if (!success) {
                uint256 len = result.length;
                assembly {
                    revert(add(result, 0x20), len)
                }
            }

            results[i] = result;
        }
    }

    /// @inheritdoc ITradingAccountBranch
    function depositMargin(uint128 accountId, address collateralType, uint256 amount) public virtual override {
        MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);
        UD60x18 ud60x18Amount = marginCollateralConfiguration.convertTokenAmountToUd60x18(amount);
        _requireAmountNotZero(ud60x18Amount);
        _requireEnoughDepositCap(collateralType, ud60x18Amount, ud60x18(marginCollateralConfiguration.depositCap));
        _requireCollateralLiquidationPriorityDefined(collateralType);

        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(accountId);
        tradingAccount.deposit(collateralType, ud60x18Amount);
        IERC20(collateralType).safeTransferFrom(msg.sender, address(this), ud60x18Amount.intoUint256());

        emit LogDepositMargin(msg.sender, accountId, collateralType, amount);
    }

    /// @inheritdoc ITradingAccountBranch
    function withdrawMargin(uint128 accountId, address collateralType, UD60x18 amount) external override {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExistingAccountAndVerifySender(accountId);
        _requireAmountNotZero(amount);
        _requireEnoughMarginCollateral(tradingAccount, collateralType, amount);

        tradingAccount.withdraw(collateralType, amount);
        _requireMarginRequirementIsValid(tradingAccount);

        MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);
        uint256 tokenAmount = marginCollateralConfiguration.convertUd60x18ToTokenAmount(amount);

        IERC20(collateralType).safeTransfer(msg.sender, tokenAmount);

        emit LogWithdrawMargin(msg.sender, accountId, collateralType, tokenAmount);
    }

    /// @inheritdoc ITradingAccountBranch
    function notifyAccountTransfer(address to, uint128 accountId) external override {
        _onlyTradingAccountToken();

        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(accountId);
        tradingAccount.owner = to;
    }

    /// @dev Reverts if the amount is zero.
    function _requireAmountNotZero(UD60x18 amount) internal pure {
        if (amount.isZero()) {
            revert Errors.ZeroInput("amount");
        }
    }

    /// @dev Reverts if the collateral type is not supported.
    function _requireEnoughDepositCap(address collateralType, UD60x18 amount, UD60x18 depositCap) internal pure {
        if (amount.gt(depositCap)) {
            revert Errors.DepositCap(collateralType, amount.intoUint256(), depositCap.intoUint256());
        }
    }

    function _requireCollateralLiquidationPriorityDefined(address collateralType) internal view {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        bool isInCollateralLiquidationPriority =
            globalConfiguration.collateralLiquidationPriority.contains(collateralType);

        if (!isInCollateralLiquidationPriority) revert Errors.CollateralLiquidationPriorityNotDefined(collateralType);
    }

    /// @notice Checks if there's enough margin collateral balance to be withdrawn.
    /// @param tradingAccount The trading account storage pointer.
    /// @param collateralType The margin collateral address.
    /// @param amount The amount of margin collateral to be withdrawn.
    function _requireEnoughMarginCollateral(
        TradingAccount.Data storage tradingAccount,
        address collateralType,
        UD60x18 amount
    )
        internal
        view
    {
        UD60x18 marginCollateralBalanceX18 = tradingAccount.getMarginCollateralBalance(collateralType);

        if (marginCollateralBalanceX18.lt(amount)) {
            revert Errors.InsufficientCollateralBalance(
                amount.intoUint256(), marginCollateralBalanceX18.intoUint256()
            );
        }
    }

    /// @dev Checks if the account will still meet margin requirements after a withdrawal.
    /// @dev Iterates over active positions in order to take uPnL and margin requirements into account.
    /// @param tradingAccount The trading account storage pointer.
    function _requireMarginRequirementIsValid(TradingAccount.Data storage tradingAccount) internal view {
        (
            UD60x18 requiredInitialMarginUsdX18,
            UD60x18 requiredMaintenanceMarginUsdX18,
            SD59x18 accountTotalUnrealizedPnlUsdX18
        ) = tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(0, SD_ZERO);
        SD59x18 marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18);

        tradingAccount.validateMarginRequirement(
            requiredInitialMarginUsdX18.add(requiredMaintenanceMarginUsdX18), marginBalanceUsdX18, SD_ZERO
        );
    }

    /// @dev Reverts if the caller is not the account owner.
    function _onlyTradingAccountToken() internal view {
        if (msg.sender != address(getTradingAccountToken())) {
            revert Errors.OnlyTradingAccountToken(msg.sender);
        }
    }
}
