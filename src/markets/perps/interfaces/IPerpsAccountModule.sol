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
    /// @return marginCollateralBalance The margin amount of the given collateral type.
    function getAccountMarginCollateralBalance(
        uint128 accountId,
        address collateralType
    )
        external
        view
        returns (UD60x18 marginCollateralBalance);

    /// @notice Returns the USD denominated total collateral value for the given account.
    /// @dev This function doesn't take open positions into account.
    /// @param accountId The trading account id.
    /// @return totalMarginCollateralValue The USD denominated total margin collateral value.
    function getTotalAccountMarginCollateralValue(uint128 accountId)
        external
        view
        returns (UD60x18 totalMarginCollateralValue);

    /// @notice Returns the account's total margin balance, available balance and maintenance margin.
    /// @dev This function does take open positions data such as unrealized pnl into account.
    /// @dev If the account's maintenance margin rate rises to 100% or above (MMR >= 1e18),
    /// the liquidation engine will be triggered.
    /// @param accountId The trading account id.
    /// @return marginBalance The account's total margin balance.
    /// @return availableMargin The account's withdrawable margin balance.
    /// @return initialMargin The account's initial margin in positions.
    /// @return maintenanceMargin The account's maintenance margin.
    function getAccountMarginBalances(uint128 accountId)
        external
        view
        returns (SD59x18 marginBalance, SD59x18 availableMargin, UD60x18 initialMargin, UD60x18 maintenanceMargin);

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
