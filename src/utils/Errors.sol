// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

library Errors {
    /// @notice Generic protocol errors

    /// @notice Thrown when the given address in a function is the zero address
    error ZeroAddress();
    /// @notice Thrown when a given input amount is zero
    error AmountZero();
    /// @notice Thrown when the sender is not authorized to perform a given action
    error Unauthorized(address sender);
    error InvalidParameter(string parameter, string reason);

    /// @notice PerpsEngine.OrderModule errors

    /// @notice Thrown when an account is liquidatable and can't perform actions
    error AccountLiquidatable(address sender, uint256 accountId);

    /// @notice PerpsEngine.PerpsAccountModule errors

    /// @notice Thrown When the provided collateral is not supported.
    error DepositCap(address collateralType, uint256 amount, uint256 depositCap);
    /// @notice Thrown When the caller is not the account token contract.
    error OnlyPerpsAccountToken(address sender);
}
