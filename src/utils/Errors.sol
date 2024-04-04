// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

/// TODO: Add require helpers in the lib.
library Errors {
    /// @notice Generic protocol errors.

    /// @notice Thrown when the given input of a function is its zero value.
    error ZeroInput(string parameter);
    /// TODO: Remove this error in the future and add meaningful errors to the functions that throw it.
    error InvalidParameter(string parameter, string reason);
    /// @notice Thrown when the sender is not authorized to perform a given action.
    error Unauthorized(address sender);
    /// @notice Thrown when two or more array parameters are expected to have the same length, but they don't.
    error ArrayLengthMismatch(uint256 expected, uint256 actual);

    /// @notice Router errors.
    error UnsupportedFunction(bytes4 functionSignature);

    /// @notice DiamondCut errors.
    error IncorrectFacetCutAction();
    error FacetIsZeroAddress();
    error FacetIsNotContract(address facet);
    error SelectorArrayEmpty(address facet);
    error SelectorIsZero();
    error FunctionAlreadyExists(bytes4 functionSelector);
    error ImmutableFacet();
    error FunctionFromSameFacet(bytes4 functionSelector);
    error NonExistingFunction(bytes4 functionSelector);
    error CannotRemoveFromOtherFacet(address facet, bytes4 functionSelector);
    error InitializableIsNotContract(address initializable);

    /// @notice Chainlink Upkeeps errors.

    /// @notice Thrown when an oracle returns an unexpected, invalid value.
    error InvalidOracleReturn();
    /// @notice Thrown when the caller is not the Chainlink Automation Forwarder.
    error OnlyForwarder(address sender, address forwarder);
    /// @notice Thrown when the upkeep provided checkData bounds are invalid.
    error InvalidBounds();

    /// @notice PerpsEngine.OrderModule errors

    /// @notice Thrown when invoking a custom settlement strategy reverts without a downstream error.
    error FailedCreateCustomOrder();
    /// @notice Thrown when trying to cancel an active market order and there's none.
    error NoActiveMarketOrder(uint128 accountId);

    /// @notice PerpsEngine.PerpsAccountModule

    /// @notice Thrown When the provided collateral is not supported.
    error DepositCap(address collateralType, uint256 amount, uint256 depositCap);
    /// @notice Thrown when there's not enough margin collateral to be withdrawn.
    error InsufficientCollateralBalance(uint256 amount, uint256 balance);
    /// @notice Thrown When the caller is not the account token contract.
    error OnlyPerpsAccountToken(address sender);
    /// @notice Thrown when the caller is not authorized by the owner of the PerpsAccount.
    error AccountPermissionDenied(uint128 accountId, address sender);
    /// @notice Thrown when the given `accountId` doesn't exist.
    error AccountNotFound(uint128 accountId, address sender);
    /// @notice Thrown when the given `accountId` tries to open a new position but it has already reached the
    /// limit.
    error MaxPositionsPerAccountReached(
        uint128 accountId, uint256 activePositionsLength, uint256 maxPositionsPerAccount
    );
    /// @notice Thrown when trying to settle an order and the account has insufficient margin for the new position.
    error InsufficientMargin(
        uint128 accountId, int256 marginBalanceUsdX18, uint256 requiredMarginUsdX18, int256 totalFeesUsdX18
    );

    /// @notice PerpsEngine.GlobalConfigurationModule

    /// @notice Thrown when the provided `accountToken` is the zero address.
    error PerpsAccountTokenNotDefined();
    /// @notice Thrown when the provided `zaros` is the zero address.
    error LiquidityEngineNotDefined();
    /// @notice Thrown when the provided `liquidationReward` is less than 1e18.
    error InvalidLiquidationReward(uint128 liquidationFeeUsdX18);
    /// @notice Thrown when `collateralType` decimals are greater than the system's decimals.
    error InvalidMarginCollateralConfiguration(address collateralType, uint8 decimals, address priceFeed);
    /// @notice Thrown when trying to update a market status but it hasn't been initialized yet.
    error PerpMarketNotInitialized(uint128 marketId);
    /// @notice Thrown when the provided `collateralType` is not in the collateral priority list when trying to remove
    /// it.
    error MarginCollateralTypeNotInPriority(address collateralType);
    /// @notice Thrown when a given trade is below the protocol configured min trade size in usd.
    error TradeSizeTooSmall();

    /// @notice PerpsEngine.SettlementModule errors.

    /// @notice Thrown when the caller is not the registered Upkeep contract.
    error OnlyUpkeep(address sender, address upkeep);

    /// @notice PerpsEngine.PerpMarketModule errors.
    // TODO: create errors

    /// @notice PerpsEngine.GlobalConfiguration errors.

    /// @notice Thrown when the provided `marketId` doesn't exist or is currently disabled.
    error PerpMarketDisabled(uint128 marketId);
    /// @notice Thrown when the provided `marketId` is already enabled when trying to enable a market.
    error PerpMarketAlreadyEnabled(uint128 marketId);
    /// @notice Thrown when the provided `marketId` is already disabled when trying to disable a market.
    error PerpMarketAlreadyDisabled(uint128 marketId);

    /// @notice PerpsEngine.LiquidationModule errors.

    error AccountNotLiquidatable(
        uint128 accountId, uint256 requiredMaintenanceMarginUsdX18, int256 marginBalanceUsdX18
    );
    error LiquidatorNotRegistered(address sender);

    /// @notice PerpsEngine.PerpMarket errors.

    /// @notice Thrown when there's no price adapter configured for a given perp market.
    error PriceAdapterNotDefined(uint128 marketId);
    /// @notice Thrown when an order tries to exceed the market's open interest cap.
    error ExceedsOpenInterestLimit(uint128 marketId, uint256 openInterest, uint256 openInterestDesired);
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

    /// @notice Thrown when a configured settlement strategy is disabled.
    error SettlementDisabled();
    /// @notice Thrown when the provided `settlementId` is not a valid settlement strategy id.
    error InvalidSettlementStrategyType(uint8 settlementId);
    /// @notice Thrown when the provided report's `reportStreamId` doesn't match the settlement configuration's
    /// one.
    error InvalidDataStreamReport(string settlementStreamId, bytes32 reportStreamId);
}
