// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

library Errors {
    /// @notice Generic protocol errors.

    /// @notice Thrown when the given input of a function is its zero value.
    error ZeroInput(string parameter);
    /// @notice General error thrown when a given parameter is invalid.
    error InvalidParameter(string parameter, string reason);
    /// @notice Thrown when the sender is not authorized to perform a given action.
    error Unauthorized(address sender);
    /// @notice Thrown when two or more array parameters are expected to have the same length, but they don't.
    error ArrayLengthMismatch(uint256 expected, uint256 actual);

    /// @notice Router errors.
    error UnsupportedFunction(bytes4 functionSignature);

    /// @notice RootUpgrade errors.
    error IncorrectBranchUpgradeAction();
    error BranchIsZeroAddress();
    error BranchIsNotContract(address branch);
    error SelectorArrayEmpty(address branch);
    error SelectorIsZero();
    error FunctionAlreadyExists(bytes4 functionSelector);
    error ImmutableBranch();
    error FunctionFromSameBranch(bytes4 functionSelector);
    error NonExistingFunction(bytes4 functionSelector);
    error CannotRemoveFromOtherBranch(address branch, bytes4 functionSelector);
    error InitializableIsNotContract(address initializable);

    /// @notice Chainlink Keepers errors.

    /// @notice Thrown when an oracle returns an unexpected, invalid value.
    error InvalidOracleReturn();
    /// @notice Thrown when the caller is not the Chainlink Automation Forwarder.
    error OnlyForwarder(address sender, address forwarder);
    /// @notice Thrown when the keeper provided checkData bounds are invalid.
    error InvalidBounds();

    /// @notice PerpsEngine.OrderBranch errors

    /// @notice Thrown when trying to cancel an active market order and there's none.
    error NoActiveMarketOrder(uint128 tradingAccountId);
    /// @notice Thrown when trying to trade and the account is eligible for liquidation.
    error AccountIsLiquidatable(uint128 tradingAccountId);
    error NewPositionSizeTooSmall();

    /// @notice PerpsEngine.TradingAccountBranch

    /// @notice Thrown When the provided collateral is not supported.
    error DepositCap(address collateralType, uint256 amount, uint256 depositCap);
    /// @notice Thrown when there's not enough margin collateral to be withdrawn.
    error InsufficientCollateralBalance(uint256 amount, uint256 balance);
    /// @notice Thrown When the caller is not the account token contract.
    error OnlyTradingAccountToken(address sender);
    /// @notice Thrown when the caller is not authorized by the owner of the TradingAccount.
    error AccountPermissionDenied(uint128 tradingAccountId, address sender);
    /// @notice Thrown when the given `tradingAccountId` doesn't exist.
    error AccountNotFound(uint128 tradingAccountId, address sender);
    /// @notice Thrown when the given `tradingAccountId` tries to open a new position but it has already reached the
    /// limit.
    error MaxPositionsPerAccountReached(
        uint128 tradingAccountId, uint256 activePositionsLength, uint256 maxPositionsPerAccount
    );
    /// @notice Thrown when trying to settle an order and the account has insufficient margin for the new position.
    error InsufficientMargin(
        uint128 tradingAccountId, int256 marginBalanceUsdX18, uint256 requiredMarginUsdX18, int256 totalFeesUsdX18
    );
    /// @notice Thrown when trying to deposit a collteral type that isn't in the liquidation priority configuration.
    error CollateralLiquidationPriorityNotDefined(address collateralType);

    /// @notice PerpsEngine.GlobalConfigurationBranch

    /// @notice Thrown when the provided `accountToken` is the zero address.
    error TradingAccountTokenNotDefined();
    /// @notice Thrown when the provided `liquidationReward` is less than 1e18.
    error InvalidLiquidationReward(uint128 liquidationFeeUsdX18);
    /// @notice Thrown when `collateralType` decimals are greater than the system's decimals.
    error InvalidMarginCollateralConfiguration(address collateralType, uint8 decimals, address priceFeed);
    /// @notice Thrown when trying to update a market status but it hasn't been initialized yet.
    error PerpMarketNotInitialized(uint128 marketId);
    /// @notice Thrown when the provided `collateralType` is not in the collateral priority list when trying to remove
    /// it.
    error MarginCollateralTypeNotInPriority(address collateralType);
    /// @notice Thrown when the provided `collateralType` is already in the collateral priority list when trying to
    /// add
    error CollateralAlreadyInPriority(address collateralType);
    /// @notice Thrown when a given trade is below the protocol configured min trade size in usd.
    error TradeSizeTooSmall();

    /// @notice PerpsEngine.SettlementBranch errors.

    /// @notice Thrown when the caller is not the registered Keeper contract.
    error OnlyKeeper(address sender, address keeper);

    /// @notice PerpsEngine.PerpMarketBranch errors.

    /// @notice PerpsEngine.GlobalConfiguration errors.

    /// @notice Thrown when the provided `marketId` doesn't exist or is currently disabled.
    error PerpMarketDisabled(uint128 marketId);
    /// @notice Thrown when the provided `marketId` is already enabled when trying to enable a market.
    error PerpMarketAlreadyEnabled(uint128 marketId);
    /// @notice Thrown when the provided `marketId` is already disabled when trying to disable a market.
    error PerpMarketAlreadyDisabled(uint128 marketId);

    /// @notice PerpsEngine.LiquidationBranch errors.

    error LiquidatorNotRegistered(address sender);

    /// @notice PerpsEngine.PerpMarket errors.

    /// @notice Thrown when there's no price adapter configured for a given perp market.
    error PriceAdapterNotDefined(uint128 marketId);
    /// @notice Thrown when an order tries to exceed the market's open interest cap.
    error ExceedsOpenInterestLimit(uint128 marketId, uint256 maxOpenInterest, uint256 newOpenInterest);
    /// @notice Thrown when an order tries to exceed the market's skew limit.
    error ExceedsSkewLimit(uint128 marketId, uint256 maxSkew, int256 newSkew);
    /// @notice Thrown when a perps market id has already been used.
    error MarketAlreadyExists(uint128 marketId);

    /// @notice PerpsEngine.MarginCollateralConfiguration errors.

    /// @notice Thrown when the {MarginCollateralConfiguration} doesn't have a price feed defined to return its price.
    error CollateralPriceFeedNotDefined();

    /// @notice PerpsEngine.MarketOrder errors.

    /// @notice Thrown when an account tries to create a new market order, and there's already an
    /// existing order with pending settlement.
    error MarketOrderStillPending(uint256 timestamp);

    /// @notice PerpsEngine.SettlementConfiguration errors.

    /// @notice Thrown when a configured settlement configuration is disabled.
    error SettlementDisabled();
    /// @notice Thrown when the provided settlement strategy for a perp market is invalid (e.g market order strategy
    /// for custom configuration).
    error InvalidSettlementStrategy();
    /// @notice Thrown when the provided report's `reportStreamId` doesn't match the settlement configuration's
    /// one.
    error InvalidDataStreamReport(bytes32 streamId, bytes32 reportStreamId);
}
