// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { MarketOrder } from "../storage/MarketOrder.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

/// @title Perps Account Module.
/// @notice This moduled is used by users in order to mint perps account nfts
/// to use them as trading subaccounts, managing their cross margin collateral and
/// trading on different perps markets.
interface IPerpsAccountModule {
    /// @notice Emitted when a new perps account is created.
    /// @param accountId The trading account id.
    /// @param sender The `msg.sender` of the create account transaction.
    event LogCreatePerpsAccount(uint128 accountId, address sender);

    /// @notice Emitted when `msg.sender` deposits `amount` of `collateralType` into `accountId`.
    /// @param sender The `msg.sender`.
    /// @param accountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The token amount of margin collateral withdrawn (token.decimals()).
    event LogDepositMargin(
        address indexed sender, uint256 indexed accountId, address indexed collateralType, uint256 amount
    );

    /// @notice Emitted when `msg.sender` withdraws `amount` of `collateralType` from `accountId`.
    /// @param sender The `msg.sender`.
    /// @param accountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The token amount of margin collateral withdrawn (token.decimals()).
    event LogWithdrawMargin(
        address indexed sender, uint256 indexed accountId, address indexed collateralType, uint256 amount
    );

    function isAuthorized(uint128 accountId, address sender) external view returns (bool isAuthorized);

    /// @notice Gets the contract address of the trading accounts NFTs.
    /// @return perpsAccountToken The account token address.
    function getPerpsAccountToken() external view returns (address perpsAccountToken);

    /// @notice Returns the account's margin amount of the given collateral type.
    /// @param accountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @return marginCollateralBalanceX18 The margin amount of the given collateral type.
    function getAccountMarginCollateralBalance(
        uint128 accountId,
        address collateralType
    )
        external
        view
        returns (UD60x18 marginCollateralBalanceX18);

    /// @notice Returns the USD denominated total collateral value for the given account.
    /// @dev This function doesn't take open positions into account.
    /// @param accountId The trading account id.
    /// @return equityUsdX18 The USD denominated total margin collateral value.
    function getAccountEquityUsd(uint128 accountId) external view returns (UD60x18 equityUsdX18);

    /// @notice Returns the account's total margin balance, available balance and maintenance margin.
    /// @dev This function does take open positions data such as unrealized pnl into account.
    /// @dev If the account's maintenance margin rate rises to 100% or above (MMR >= 1e18),
    /// the liquidation engine will be triggered.
    /// @param accountId The trading account id.
    /// @return marginBalanceUsdX18 The account's total margin balance.
    /// @return availableMarginUsdX18 The account's withdrawable margin balance.
    /// @return initialMarginUsdX18 The account's initial margin in positions.
    /// @return maintenanceMarginUsdX18 The account's maintenance margin.
    function getAccountMarginBreakdown(uint128 accountId)
        external
        view
        returns (
            SD59x18 marginBalanceUsdX18,
            SD59x18 availableMarginUsdX18,
            UD60x18 initialMarginUsdX18,
            UD60x18 maintenanceMarginUsdX18
        );

    /// @notice Gets the given market's open position details.
    /// @param accountId The perps account id.
    /// @param marketId The perps market id.
    /// @param indexPriceX18 The current index price of the market.
    /// @return size The position openInterest in asset units, i.e amount of purchased contracts.
    /// @return notionalValueUsdX18 The notional value of the position.
    /// @return maintenanceMarginUsdX18 The notional value of the maintenance margin allocated by the account.
    /// @return accruedFundingUsdX18 The accrued funding fee.
    /// @return unrealizedPnlUsdX18 The current unrealized profit or loss of the position.
    function getOpenPositionData(
        uint128 accountId,
        uint128 marketId,
        uint256 indexPriceX18
    )
        external
        view
        returns (
            SD59x18 size,
            UD60x18 notionalValueUsdX18,
            UD60x18 maintenanceMarginUsdX18,
            SD59x18 accruedFundingUsdX18,
            SD59x18 unrealizedPnlUsdX18
        );

    /// @notice Creates a new trading account and mints its NFT
    /// @return accountId The trading account id.
    function createPerpsAccount() external returns (uint128 accountId);

    /// @notice Creates a new trading account and multicalls using the provided data payload.
    /// @param data The data payload to be multicalled.
    /// @return results The array of results of the multicall.
    function createPerpsAccountAndMulticall(bytes[] calldata data)
        external
        payable
        returns (bytes[] memory results);

    /// @notice Deposits margin collateral into the given trading account.
    /// @param accountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The amount of margin collateral to deposit.
    function depositMargin(uint128 accountId, address collateralType, uint256 amount) external;

    /// @notice Withdraws available margin collateral from the given trading account.
    /// @param accountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param ud60x18Amount The UD60x18 amount of margin collateral to withdraw.
    function withdrawMargin(uint128 accountId, address collateralType, UD60x18 ud60x18Amount) external;

    /// @notice Used by the Account NFT contract to notify an account transfer.
    /// @dev Can only be called by the Account NFT contract.
    /// @dev It updates the Perps Account stored access control data.
    /// @param to The recipient of the account transfer.
    /// @param accountId The trading account id.
    function notifyAccountTransfer(address to, uint128 accountId) external;
}
