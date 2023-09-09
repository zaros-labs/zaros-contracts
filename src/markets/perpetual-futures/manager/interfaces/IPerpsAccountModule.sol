// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Order } from "../../market/storage/Order.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

interface IPerpsAccountModule {
    error Zaros_PerpsAccountModule_InvalidCollateralType(address collateralType);
    error Zaros_PerpsAccountModule_OnlyAccountToken(address sender);

    event LogCreatePerpsAccount(uint256 accountId, address sender);
    event LogDepositMargin(address indexed sender, address indexed collateralType, uint256 amount);
    event LogWithdrawMargin(address indexed sender, address indexed collateralType, uint256 amount);

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

    function createAccount() external returns (uint128);

    function createAccountAndMulticall(bytes[] calldata data) external payable returns (bytes[] memory results);

    function depositMargin(uint256 accountId, address collateralType, uint256 amount) external;

    function withdrawMargin(uint256 accountId, address collateralType, uint256 amount) external;

    function notifyAccountTransfer(address to, uint128 accountId) external;
}
