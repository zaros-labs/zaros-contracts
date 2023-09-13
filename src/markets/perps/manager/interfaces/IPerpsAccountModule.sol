// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Order } from "../../market/storage/Order.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

/// @title Module for managing perps trading accounts.
/// @notice Users can mint perps account nfts and use as trading subaccounts, managing
/// their cross margin collateral and trade on different perps markets.
interface IPerpsAccountModule {
    /// @notice Thrown When the provided collateral is not supported.
    error Zaros_PerpsAccountModule_InvalidCollateralType(address collateralType);
    /// @notice Thrown When the caller is not the account token contract.
    error Zaros_PerpsAccountModule_OnlyAccountToken(address sender);

    /// @notice Emitted when a new perps account is created.
    /// @param accountId The trading account id.
    /// @param sender The `msg.sender` of the create account transaction.
    event LogCreatePerpsAccount(uint256 accountId, address sender);

    /// @notice Emitted when `msg.sender` deposits `amount` of `collateralType` into `accountId`.
    /// @param sender The `msg.sender`.
    /// @param accountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The amount of margin collateral deposited.
    event LogDepositMargin(
        address indexed sender, uint256 indexed accountId, address indexed collateralType, uint256 amount
    );

    /// @notice Emitted when `msg.sender` withdraws `amount` of `collateralType` from `accountId`.
    /// @param sender The `msg.sender`.
    /// @param accountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The amount of margin collateral withdrawn.
    event LogWithdrawMargin(
        address indexed sender, uint256 indexed accountId, address indexed collateralType, uint256 amount
    );

    /// @notice Gets the contract address of the trading accounts NFTs.
    /// @return accountToken The account token address.
    function getAccountTokenAddress() external view returns (address);

    /// @notice Returns the account's margin amount of the given collateral type.
    /// @param accountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @return marginCollateral The margin amount of the given collateral type.
    function getAccountMarginCollateral(
        uint256 accountId,
        address collateralType
    )
        external
        view
        returns (UD60x18 marginCollateral);

    /// @notice Returns the USD denominated total collateral value for the given account.
    /// @dev This function doesn't take open positions into account.
    /// @param accountId The trading account id.
    /// @return totalMarginCollateralValue The USD denominated total margin collateral value.
    function getTotalAccountMarginCollateralValue(uint256 accountId)
        external
        view
        returns (UD60x18 totalMarginCollateralValue);

    /// @notice Returns the account's total margin balance and available balance.
    /// @dev This function does take open positions data such as unrealized pnl into account.
    /// @param accountId The trading account id.
    /// @return marginBalance The account's total margin balance.
    /// @return availableMargin The account's withdrawable margin balance.
    function getAccountMargin(uint256 accountId)
        external
        view
        returns (UD60x18 marginBalance, UD60x18 availableMargin);

    /// @notice Creates a new trading account and mints its NFT
    /// @return accountId The trading account id.
    function createPerpsAccount() external returns (uint256 accountId);

    /// @notice Creates a new trading account and multicalls using the provided data payload.
    /// @param data The data payload to be multicalled.
    /// @return results The array of results of the multicall.
    function createPerpsAccountAndMulticall(bytes[] calldata data) external payable returns (bytes[] memory results);

    /// @notice Deposits margin collateral into the given trading account.
    /// @param accountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The amount of margin collateral to deposit.
    function depositMargin(uint256 accountId, address collateralType, uint256 amount) external;

    /// @notice Withdraws available margin collateral from the given trading account.
    /// @param accountId The trading account id.
    /// @param collateralType The margin collateral address.
    /// @param amount The amount of margin collateral to withdraw.
    function withdrawMargin(uint256 accountId, address collateralType, uint256 amount) external;

    /// @notice Used by the Account NFT contract to notify an account transfer.
    /// @dev Can only be called by the Account NFT contract.
    /// @dev It updates the Perps Account stored access control data.
    /// @param to The recipient of the account transfer.
    /// @param accountId The trading account id.
    function notifyAccountTransfer(address to, uint128 accountId) external;
}
