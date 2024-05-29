// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { IAccountNFT } from "@zaros/account-nft/interfaces/IAccountNFT.sol";
import { Errors } from "@zaros/utils/Errors.sol";
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

/// @title Trading Account Branch.
/// @notice This branch is used by users in order to mint trading account nfts
/// to use them as trading subaccounts, managing their cross margin collateral and
/// trading on different perps markets.
contract TradingAccountBranch {
    using EnumerableSet for *;
    using TradingAccount for TradingAccount.Data;
    using PerpMarket for PerpMarket.Data;
    using Position for Position.Data;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using GlobalConfiguration for GlobalConfiguration.Data;
    using MarginCollateralConfiguration for MarginCollateralConfiguration.Data;

    /// @notice Emitted when a new trading account is created.
    /// @param tradingAccountId The trading account id.
    /// @param sender The `msg.sender` of the create account transaction.
    event LogCreateTradingAccount(uint128 tradingAccountId, address sender);

    /// @notice Emitted when `msg.sender` deposits `amount` of `collateralType` into `tradingAccountId`.
    /// @param sender The `msg.sender`.
    /// @param tradingAccountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The token amount of margin collateral withdrawn (token.decimals()).
    event LogDepositMargin(
        address indexed sender, uint128 indexed tradingAccountId, address indexed collateralType, uint256 amount
    );

    /// @notice Emitted when `msg.sender` withdraws `amount` of `collateralType` from `tradingAccountId`.
    /// @param sender The `msg.sender`.
    /// @param tradingAccountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The token amount of margin collateral withdrawn (token.decimals()).
    event LogWithdrawMargin(
        address indexed sender, uint128 indexed tradingAccountId, address indexed collateralType, uint256 amount
    );

    /// @notice Gets the contract address of the trading accounts NFTs.
    /// @return tradingAccountToken The account token address.
    function getTradingAccountToken() public view returns (address) {
        return GlobalConfiguration.load().tradingAccountToken;
    }

    /// @notice Returns the account's margin amount of the given collateral type.
    /// @param tradingAccountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @return marginCollateralBalanceX18 The margin amount of the given collateral type.
    function getAccountMarginCollateralBalance(
        uint128 tradingAccountId,
        address collateralType
    )
        external
        view
        returns (UD60x18)
    {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);
        UD60x18 marginCollateralBalanceX18 = tradingAccount.getMarginCollateralBalance(collateralType);

        return marginCollateralBalanceX18;
    }

    /// @notice Returns the total equity of all assets under the trading account without considering the collateral
    /// value
    /// ratio
    /// @dev This function doesn't take open positions into account.
    /// @param tradingAccountId The trading account id.
    /// @return equityUsdX18 The USD denominated total margin collateral value.
    function getAccountEquityUsd(uint128 tradingAccountId) external view returns (SD59x18) {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);
        SD59x18 activePositionsUnrealizedPnlUsdX18 = tradingAccount.getAccountUnrealizedPnlUsd();

        return tradingAccount.getEquityUsd(activePositionsUnrealizedPnlUsdX18);
    }

    /// @notice Returns the trading account's total margin balance, available balance and maintenance margin.
    /// @dev This function does take open positions data such as unrealized pnl into account.
    /// @dev The margin balance value takes into account the margin collateral's configured ratio (LTV).
    /// @dev If the account's maintenance margin rate rises to 100% or above (MMR >= 1e18),
    /// the liquidation engine will be triggered.
    /// @param tradingAccountId The trading account id.
    /// @return marginBalanceUsdX18 The account's total margin balance.
    /// @return initialMarginUsdX18 The account's initial margin in positions.
    /// @return maintenanceMarginUsdX18 The account's maintenance margin.
    /// @return availableMarginUsdX18 The account's withdrawable margin balance.
    function getAccountMarginBreakdown(uint128 tradingAccountId)
        external
        view
        returns (
            SD59x18 marginBalanceUsdX18,
            UD60x18 initialMarginUsdX18,
            UD60x18 maintenanceMarginUsdX18,
            SD59x18 availableMarginUsdX18
        )
    {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);
        SD59x18 activePositionsUnrealizedPnlUsdX18 = tradingAccount.getAccountUnrealizedPnlUsd();

        marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(activePositionsUnrealizedPnlUsdX18);

        for (uint256 i = 0; i < tradingAccount.activeMarketsIds.length(); i++) {
            uint128 marketId = tradingAccount.activeMarketsIds.at(i).toUint128();

            PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
            Position.Data storage position = Position.load(tradingAccountId, marketId);

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

        availableMarginUsdX18 = marginBalanceUsdX18.sub((initialMarginUsdX18).intoSD59x18());
    }

    /// @notice Returns the total trading account's unrealized pnl across open positions.
    /// @param tradingAccountId The trading account id.
    /// @return accountTotalUnrealizedPnlUsdX18 The account's total unrealized pnl.
    function getAccountTotalUnrealizedPnl(uint128 tradingAccountId)
        external
        view
        returns (SD59x18 accountTotalUnrealizedPnlUsdX18)
    {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);
        accountTotalUnrealizedPnlUsdX18 = tradingAccount.getAccountUnrealizedPnlUsd();
    }

    /// @notice Returns the current leverage of a given account id, based on its cross margin collateral and open
    /// positions.
    /// @param tradingAccountId The trading account id.
    /// @return leverage The account leverage.
    function getAccountLeverage(uint128 tradingAccountId) external view returns (UD60x18) {
        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);

        SD59x18 marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(tradingAccount.getAccountUnrealizedPnlUsd());
        UD60x18 totalPositionsNotionalValue;

        for (uint256 i = 0; i < tradingAccount.activeMarketsIds.length(); i++) {
            uint128 marketId = tradingAccount.activeMarketsIds.at(i).toUint128();

            PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
            Position.Data storage position = Position.load(tradingAccountId, marketId);

            UD60x18 indexPrice = perpMarket.getIndexPrice();
            UD60x18 markPrice = perpMarket.getMarkPrice(unary(sd59x18(position.size)), indexPrice);

            UD60x18 positionNotionalValueX18 = position.getNotionalValue(markPrice);
            totalPositionsNotionalValue = totalPositionsNotionalValue.add(positionNotionalValueX18);
        }

        return marginBalanceUsdX18.isZero()
            ? marginBalanceUsdX18.intoUD60x18()
            : totalPositionsNotionalValue.intoSD59x18().div(marginBalanceUsdX18).intoUD60x18();
    }

    /// @notice Gets the given market's position state.
    /// @param tradingAccountId The trading account id.
    /// @param marketId The perps market id.
    /// @param indexPrice The market's offchain index price.
    /// @return positionState The position's current state.
    function getPositionState(
        uint128 tradingAccountId,
        uint128 marketId,
        uint256 indexPrice
    )
        external
        view
        returns (Position.State memory positionState)
    {
        PerpMarket.Data storage perpMarket = PerpMarket.load(marketId);
        Position.Data storage position = Position.load(tradingAccountId, marketId);

        UD60x18 markPriceX18 = perpMarket.getMarkPrice(unary(sd59x18(position.size)), ud60x18(indexPrice));
        SD59x18 fundingFeePerUnit =
            perpMarket.getNextFundingFeePerUnit(perpMarket.getCurrentFundingRate(), markPriceX18);

        positionState = position.getState(
            ud60x18(perpMarket.configuration.initialMarginRateX18),
            ud60x18(perpMarket.configuration.maintenanceMarginRateX18),
            markPriceX18,
            fundingFeePerUnit
        );
    }

    /// @notice Creates a new trading account and mints its NFT
    /// @return tradingAccountId The trading account id.
    function createTradingAccount() public virtual returns (uint128) {
        GlobalConfiguration.Data storage globalConfiguration = GlobalConfiguration.load();
        uint128 tradingAccountId = ++globalConfiguration.nextAccountId;
        IAccountNFT tradingAccountToken = IAccountNFT(globalConfiguration.tradingAccountToken);
        TradingAccount.create(tradingAccountId, msg.sender);

        tradingAccountToken.mint(msg.sender, tradingAccountId);

        emit LogCreateTradingAccount(tradingAccountId, msg.sender);
        return tradingAccountId;
    }

    /// @notice Creates a new trading account and multicalls using the provided data payload.
    /// @param data The data payload to be multicalled.
    /// @return results The array of results of the multicall.
    function createTradingAccountAndMulticall(bytes[] calldata data)
        external
        payable
        virtual
        returns (bytes[] memory results)
    {
        uint128 tradingAccountId = createTradingAccount();

        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            bytes memory dataWithAccountId = bytes.concat(data[i][0:4], abi.encode(tradingAccountId), data[i][4:]);
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

    /// @notice Deposits margin collateral into the given trading account.
    /// @param tradingAccountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The amount of margin collateral to deposit.
    function depositMargin(uint128 tradingAccountId, address collateralType, uint256 amount) public virtual {
        MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);
        UD60x18 ud60x18Amount = marginCollateralConfiguration.convertTokenAmountToUd60x18(amount);
        _requireAmountNotZero(ud60x18Amount);
        _requireEnoughDepositCap(collateralType, ud60x18Amount, ud60x18(marginCollateralConfiguration.depositCap));
        _requireCollateralLiquidationPriorityDefined(collateralType);

        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);
        tradingAccount.deposit(collateralType, ud60x18Amount);
        IERC20(collateralType).safeTransferFrom(msg.sender, address(this), ud60x18Amount.intoUint256());

        emit LogDepositMargin(msg.sender, tradingAccountId, collateralType, amount);
    }

    /// @notice Withdraws available margin collateral from the given trading account.
    /// @param tradingAccountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The UD60x18 amount of margin collateral to withdraw.
    function withdrawMargin(uint128 tradingAccountId, address collateralType, uint256 amount) external {
        MarginCollateralConfiguration.Data storage marginCollateralConfiguration =
            MarginCollateralConfiguration.load(collateralType);

        TradingAccount.Data storage tradingAccount =
            TradingAccount.loadExistingAccountAndVerifySender(tradingAccountId);

        UD60x18 ud60x18Amount = marginCollateralConfiguration.convertTokenAmountToUd60x18(amount);

        _requireAmountNotZero(ud60x18Amount);
        _requireEnoughMarginCollateral(tradingAccount, collateralType, ud60x18Amount);

        tradingAccount.withdraw(collateralType, ud60x18Amount);
        (UD60x18 requiredInitialMarginUsdX18,, SD59x18 accountTotalUnrealizedPnlUsdX18) =
            tradingAccount.getAccountMarginRequirementUsdAndUnrealizedPnlUsd(0, SD_ZERO);
        SD59x18 marginBalanceUsdX18 = tradingAccount.getMarginBalanceUsd(accountTotalUnrealizedPnlUsdX18);

        tradingAccount.validateMarginRequirement(requiredInitialMarginUsdX18, marginBalanceUsdX18, SD_ZERO);

        uint256 tokenAmount = marginCollateralConfiguration.convertUd60x18ToTokenAmount(ud60x18Amount);

        IERC20(collateralType).safeTransfer(msg.sender, tokenAmount);

        emit LogWithdrawMargin(msg.sender, tradingAccountId, collateralType, tokenAmount);
    }

    /// @notice Used by the Account NFT contract to notify an account transfer.
    /// @dev Can only be called by the Account NFT contract.
    /// @dev It updates the Trading Account stored access control data.
    /// @param to The recipient of the account transfer.
    /// @param tradingAccountId The trading account id.
    function notifyAccountTransfer(address to, uint128 tradingAccountId) external {
        _onlyTradingAccountToken();

        TradingAccount.Data storage tradingAccount = TradingAccount.loadExisting(tradingAccountId);
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

    /// @dev Reverts if the caller is not the account owner.
    function _onlyTradingAccountToken() internal view {
        if (msg.sender != address(getTradingAccountToken())) {
            revert Errors.OnlyTradingAccountToken(msg.sender);
        }
    }
}
