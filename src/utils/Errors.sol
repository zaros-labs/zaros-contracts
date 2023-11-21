// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

library Errors {
    /// @notice Generic protocol errors

    /// @notice Thrown when the given input of a function is its zero value
    error ZeroInput(string parameter);
    /// @notice Thrown when the sender is not authorized to perform a given action
    error Unauthorized(address sender);

    /// @notice PerpsEngine.OrderModule errors

    /// @notice Thrown when an account is liquidatable and can't perform actions
    error AccountLiquidatable(address sender, uint256 accountId);

    /// @notice PerpsEngine.PerpsAccountModule errors

    /// @notice Thrown When the provided collateral is not supported.
    error DepositCap(address collateralType, uint256 amount, uint256 depositCap);
    /// @notice Thrown When the caller is not the account token contract.
    error OnlyPerpsAccountToken(address sender);

    /// @notice PerpsEngine.PerpsConfigurationModule

    /// @notice Thrown when the provided `accountToken` is the zero address.
    error PerpsAccountTokenNotDefined();
    /// @notice Thrown when the provided `zaros` is the zero address.
    error LiquidityEngineNotDefined();
    /// @notice Thrown when `collateralType` decimals are greater than the system's decimals.
    error InvalidMarginCollateralConfiguration(address collateralType, uint8 decimals, address priceFeed);
}
