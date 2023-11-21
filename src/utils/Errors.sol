// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

library Errors {
    /// @notice Generic protocol errors.

    /// @notice Thrown when the given input of a function is its zero value.
    error ZeroInput(string parameter);
    /// TODO: Remove this error in the future and add meaningful errors to the functions that throw it.
    error InvalidParameter(string parameter, string reason);
    /// @notice Thrown when the sender is not authorized to perform a given action.
    error Unauthorized(address sender);

    /// @notice PerpsEngine.OrderModule errors

    /// @notice Thrown when an account is liquidatable and can't perform actions
    error AccountLiquidatable(address sender, uint256 accountId);

    /// @notice PerpsEngine.PerpsAccountModule and PerpsEngine.PerpsAccount errors.

    /// @notice Thrown When the provided collateral is not supported.
    error DepositCap(address collateralType, uint256 amount, uint256 depositCap);
    /// @notice Thrown When the caller is not the account token contract.
    error OnlyPerpsAccountToken(address sender);
    /// @notice Thrown when the caller is not authorized by the owner of the PerpsAccount.
    error PermissionDenied(uint256 accountId, address sender);
    /// @notice Thrown when the given `accountId` doesn't exist.
    error AccountNotFound(uint256 accountId, address sender);

    /// @notice PerpsEngine.PerpsConfigurationModule

    /// @notice Thrown when the provided `accountToken` is the zero address.
    error PerpsAccountTokenNotDefined();
    /// @notice Thrown when the provided `zaros` is the zero address.
    error LiquidityEngineNotDefined();
    /// @notice Thrown when `collateralType` decimals are greater than the system's decimals.
    error InvalidMarginCollateralConfiguration(address collateralType, uint8 decimals, address priceFeed);

    /// @notice PerpsEngine.SettlementModule errors

    /// @notice Thrown when the caller is not the Chainlink Automation Forwarder.
    error OnlyForwarder(address sender, address forwarder);

    /// @notice PerpsEngine.PerpsMarketModule and PerpsEngine.PerpsMarket errors.

    /// @notice Thrown when a perps market id has already been used.
    error MarketAlreadyExists(uint128 marketId, address sender);

    /// @notice PerpsEngine.MarginCollateral errors.

    /// @notice Thrown when the {MarginCollateral} doesn't have a price feed defined to return its price.
    error CollateralPriceFeedNotDefined();
}
