// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { MarketOrder } from "../leaves/MarketOrder.sol";
import { Position } from "../leaves/Position.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

/// @title Trading Account Branch.
/// @notice This branch is used by users in order to mint trading account nfts
/// to use them as trading subaccounts, managing their cross margin collateral and
/// trading on different perps markets.
interface ITradingAccountBranch {
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
    function getTradingAccountToken() external view returns (address tradingAccountToken);

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
        returns (UD60x18 marginCollateralBalanceX18);

    /// @notice Returns the total equity of all assets under the trading account without considering the collateral
    /// value
    /// ratio
    /// @dev This function doesn't take open positions into account.
    /// @param tradingAccountId The trading account id.
    /// @return equityUsdX18 The USD denominated total margin collateral value.
    function getAccountEquityUsd(uint128 tradingAccountId) external view returns (SD59x18 equityUsdX18);

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
        );

    /// @notice Returns the total trading account's unrealized pnl across open positions.
    /// @param tradingAccountId The trading account id.
    /// @return accountTotalUnrealizedPnlUsdX18 The account's total unrealized pnl.
    function getAccountTotalUnrealizedPnl(uint128 tradingAccountId)
        external
        view
        returns (SD59x18 accountTotalUnrealizedPnlUsdX18);

    /// @notice Returns the current leverage of a given account id, based on its cross margin collateral and open
    /// positions.
    /// @param tradingAccountId The trading account id.
    /// @return leverage The account leverage.
    function getAccountLeverage(uint128 tradingAccountId) external view returns (UD60x18 leverage);

    /// @notice Gets the given market's position state.
    /// @param tradingAccountId The trading account id.
    /// @param marketId The perps market id.
    /// @return positionState The position's current state.
    function getPositionState(
        uint128 tradingAccountId,
        uint128 marketId
    )
        external
        view
        returns (Position.State memory positionState);

    /// @notice Creates a new trading account and mints its NFT
    /// @return tradingAccountId The trading account id.
    function createTradingAccount() external returns (uint128 tradingAccountId);

    /// @notice Creates a new trading account and multicalls using the provided data payload.
    /// @param data The data payload to be multicalled.
    /// @return results The array of results of the multicall.
    function createTradingAccountAndMulticall(bytes[] calldata data)
        external
        payable
        returns (bytes[] memory results);

    /// @notice Deposits margin collateral into the given trading account.
    /// @param tradingAccountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The amount of margin collateral to deposit.
    function depositMargin(uint128 tradingAccountId, address collateralType, uint256 amount) external;

    /// @notice Withdraws available margin collateral from the given trading account.
    /// @param tradingAccountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param ud60x18Amount The UD60x18 amount of margin collateral to withdraw.
    function withdrawMargin(uint128 tradingAccountId, address collateralType, UD60x18 ud60x18Amount) external;

    /// @notice Used by the Account NFT contract to notify an account transfer.
    /// @dev Can only be called by the Account NFT contract.
    /// @dev It updates the Trading Account stored access control data.
    /// @param to The recipient of the account transfer.
    /// @param tradingAccountId The trading account id.
    function notifyAccountTransfer(address to, uint128 tradingAccountId) external;
}
