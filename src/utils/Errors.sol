// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

library Errors {
    /// @notice Generic protocol errors.

    /// @notice Thrown when the given input of a function is its zero value.
    error ZeroInput(string parameter);
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

    /// @notice Thrown when an oracle aggregator returns an answer out of range of min and max.
    error OraclePriceFeedOutOfRange(address priceFeed);
    /// @notice Thrown when an oracle sequencer uptime feed returns an unexpected, invalid value.
    error InvalidSequencerUptimeFeedReturn(address sequencerUptimeFeedAddress);
    /// @notice Thrown when an oracle sequencer uptime feed returns an unexpected, invalid value.
    error OracleSequencerUptimeFeedIsDown(address sequencerUptimeFeed);
    /// @notice Thrown when an oracle grace period is not over.
    error GracePeriodNotOver(address sequencerUptimeFeedAddress);
    /// @notice Thrown when an oracle returns an unexpected, invalid value.
    error InvalidOracleReturn();
    /// @notice Thrown when an oracle price feed is outdated.
    error OraclePriceFeedHeartbeat(address priceFeed);
    /// @notice Thrown when the keeper provided checkData bounds are invalid.
    error InvalidBounds();
    /// @notice Thrown when an oracle sequencer is not started.
    error OracleSequencerUptimeFeedNotStarted(address sequencerUptimeFeedAddress);

    /// @notice PerpsEngine.OrderBranch errors

    /// @notice Thrown when trying to cancel an active market order and there's none.
    error NoActiveMarketOrder(uint128 tradingAccountId);
    /// @notice Thrown when trying to trade and the account is eligible for liquidation.
    error AccountIsLiquidatable(uint128 tradingAccountId);
    error NewPositionSizeTooSmall();

    /// @notice PerpsEngine.TradingAccountBranch

    /// @notice Thrown When the provided amount in 18 decimals of collateral exceeds the deposit cap.
    error DepositCap(address collateralType, uint256 amountX18, uint256 depositCapX18);
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
        uint128 tradingAccountId, int256 marginBalanceUsdX18, uint256 requiredMarginUsdX18, uint256 totalFeesUsdX18
    );
    /// @notice Thrown when trying to deposit a collteral type that isn't in the liquidation priority configuration.
    error CollateralLiquidationPriorityNotDefined(address collateralType);
    /// @notice Thrown when the provided referral code is invalid.
    error InvalidReferralCode();

    /// @notice PerpsEngine.PerpsEngineConfigurationBranch

    /// @notice Thrown when the provided `sequencerUptimeFeed` is the zero address.
    error SequencerUptimeFeedNotDefined();
    /// @notice Thrown when the provided `accountToken` is the zero address.
    error TradingAccountTokenNotDefined();
    /// @notice Thrown when `collateralType` decimals are greater than the system's decimals.
    error InvalidMarginCollateralConfiguration(address collateralType, uint8 decimals, address priceFeed);
    /// @notice Thrown when trying to update a market status but it hasn't been initialized yet.
    error PerpMarketNotInitialized(uint128 marketId);
    /// @notice Thrown when the provided `collateralType` is not in the collateral priority list when trying to remove
    /// it.
    error MarginCollateralTypeNotInPriority(address collateralType);
    /// @notice Thrown when the provided `collateralType` is already in the collateral priority list when trying to
    /// add
    error MarginCollateralAlreadyInPriority(address collateralType);
    /// @notice Thrown when a given trade is below the protocol configured min trade size in usd.
    error TradeSizeTooSmall();
    /// @notice Thrown when the provided `initialMarginRate` is less or equal than the `maintenanceMarginRate`.
    error InitialMarginRateLessOrEqualThanMaintenanceMarginRate();

    /// @notice PerpsEngine.SettlementBranch errors.

    /// @notice Thrown when the selected market id mismatch with the order's market id.
    error OrderMarketIdMismatch(uint128 marketId, uint128 orderMarketId);

    /// @notice Thrown when the caller is not the registered Keeper contract.
    error OnlyKeeper(address sender, address keeper);
    /// @notice Thrown when the signed `nonce` of a given order is not equal to the trading account's current nonce.
    error InvalidSignedNonce(uint128 tradingAccountNonce, uint120 orderNonce);
    /// @notice Thrown when an order signed by the `tradingAccountId` owner using the given `salt` has already been
    /// filled.
    error OrderAlreadyFilled(uint128 tradingAccountId, bytes32 salt);
    /// @notice Thrown when the recovered ECDSA signer of an offchain order is not the trading account owner.
    error InvalidOrderSigner(address signer, address expectedSigner);

    /// @notice PerpsEngine.PerpMarketBranch errors.

    /// @notice PerpsEngine.PerpsEngineConfiguration errors.

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
    /// @notice Thrown when the provided settlement configuration id does not exist.
    error InvalidSettlementConfigurationId();
    /// @notice Thrown when the provided report's `reportStreamId` doesn't match the settlement configuration's
    /// one.
    error InvalidDataStreamReport(bytes32 streamId, bytes32 reportStreamId);

    /// @notice MarketMakingEngine.CreditDelegationBranch errors.

    /// @notice Thrown when the given `marketId` has no vaults delegating credit to it. This error must be unreachable
    /// and treated as a panic state.
    error NoConnectedVaults(uint128 marketId);
    /// @notice Thrown when trying to realize debt but the market has a credit capacity <= 0. The ADL
    /// system and LP's collateral risk parameters are built to prevent this error from being thrown.
    error InsufficientCreditCapacity(uint128 marketId, int256 creditCapacityUsd);
    /// @notice Thrown when trying to distribute value to an empty vaults debt distribution.
    /// NOTE: This error must be unreachable as the system enforces market to have a minimum delegated credit through
    /// Vault.Data.lockedCreditRatio.
    error NoDelegatedCredit(uint128 marketId);

    /// @notice MarketMakingEngine.Collateral errors.
    error CollateralDisabled(address collateralType);

    /// @notice MarketMakingEngine.Distribution errors.

    /// @notice Thrown when trying to distribute value to an empty distribution.
    error EmptyDistribution();

    /// @notice MarketMakingEngine.VaultRouterBranch errors

    /// @notice Thrown when a slippage check fails.
    error SlippageCheckFailed();

    /// @notice Thrown when a user does not have enough shares.
    error NotEnoughShares();

    /// @notice Thrown when a withdrawal is attempted before the required delay has passed.
    error WithdrawDelayNotPassed();

    /// @notice Thrown when a withdraw request is fulfiled.
    error WithdrawalRequestAlreadyFullfilled();

    /// @notice Thrown when vault with the given id already exists.
    /// @param vaultId The ID of the vault to create.
    error VaultAlreadyExists(uint256 vaultId);

    /// @notice Thrown when vault does NOT exist
    /// @param vaultId The ID of the vault that does NOT exist.
    error VaultDoesNotExist(uint128 vaultId);

    /// @notice Thrown when vault is NOT live.
    /// @dev A vault could be paused by setting its `isLive` flag to false.
    /// @param vaultId The ID of the vault that is NOT live.
    error VaultIsDisabled(uint128 vaultId);

    /// @notice MarketMakingEngine.Vault errors.
    error NoMarketsConnectedToVault(uint128 vaultId);
}
