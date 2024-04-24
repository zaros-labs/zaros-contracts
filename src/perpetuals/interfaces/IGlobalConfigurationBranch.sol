// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { MarginCollateralConfiguration } from "../leaves/MarginCollateralConfiguration.sol";
import { OrderFees } from "../leaves/OrderFees.sol";
import { SettlementConfiguration } from "../leaves/SettlementConfiguration.sol";

/// @title Global Configuration Branch.
/// @notice This  is used by the protocol controller to configure the perps
/// exchange system.
interface IGlobalConfigurationBranch {
    /// @notice Emitted when the account token address is set.
    event LogSetPerpsAccountToken(address indexed sender, address indexed perpsAccountToken);

    /// @notice Emitted when the Liquidity Engine address is set.
    /// @param sender The address that set the Liquidity Engine address.
    /// @param liquidityEngine The Liquidity Engine address.
    event LogSetLiquidityEngine(address indexed sender, address indexed liquidityEngine);

    /// @notice Emitted when the collateral priority is configured.
    /// @param sender The address that configured the collateral priority.
    /// @param collateralTypes The array of collateral type addresses, ordered by priority.
    event LogConfigureCollateralPriority(address indexed sender, address[] collateralTypes);

    /// @notice Emitted when the liquidators are configured.
    /// @param sender The address that configured the liquidators.
    /// @param liquidators The array of liquidator addresses.
    /// @param enable The array of boolean values that enable or disable the liquidator.
    event LogConfigureLiquidators(address indexed sender, address[] liquidators, bool[] enable);

    /// @notice Emitted when a new collateral type is enabled or disabled.
    /// @param sender The address that enabled or disabled the collateral type.
    /// @param collateralType The address of the collateral type.
    /// @param depositCap The maximum amount of collateral that can be deposited.
    /// @param decimals The amount of decimals of the collateral type's ERC20 token.
    /// @param priceFeed The price oracle address.
    event LogConfigureMarginCollateral(
        address indexed sender, address indexed collateralType, uint128 depositCap, uint8 decimals, address priceFeed
    );

    /// @notice Emitted when a collateral type is removed from the collateral priority.
    /// @param sender The address that removed the collateral type from the priority list.
    /// @param collateralType The address of the collateral type.
    event LogRemoveCollateralFromPriorityList(address indexed sender, address indexed collateralType);

    /// @notice Emitted when the global system parameters are configured.
    /// @param sender The address that configured the system parameters.
    /// @param maxPositionsPerAccount The maximum number of open positions per account.
    /// @param marketOrderMaxLifetime The maximum lifetime of a market order to be considered active.
    /// @param liquidationFeeUsdX18 The liquidation fee in USD.
    event LogConfigureSystemParameters(
        address indexed sender,
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMaxLifetime,
        uint128 liquidationFeeUsdX18
    );

    /// @notice Emitted when a new perps market is created.
    /// @param sender The address that configured the price feed.
    /// @param marketId The perps market id.
    event LogCreatePerpMarket(address indexed sender, uint128 marketId);

    /// @notice Emitted when a perps market is reconfigured.
    /// @param sender The address that configured the perps market.
    /// @param marketId The perps market id.
    event LogConfigurePerpMarket(address indexed sender, uint128 marketId);

    /// @notice Emitted when the settlement configuration of a given market is updated.
    /// @param sender The address that updated the settlement configuration.
    /// @param marketId The perps market id.
    /// @param settlementConfigurationId The perps market settlement configuration id.
    event LogUpdateSettlementConfiguration(
        address indexed sender, uint128 indexed marketId, uint128 settlementConfigurationId
    );

    /// @notice Emitted when a perp market is re-enabled by the owner.
    /// @param marketId The perps market id.
    event LogEnablePerpMarket(address indexed sender, uint128 marketId);

    /// @notice Emitted when a perp market is disabled by the owner.
    /// @param marketId The perps market id.
    event LogDisablePerpMarket(address indexed sender, uint128 marketId);

    function getAccountsWithActivePositions(
        uint256 lowerBound,
        uint256 upperBound
    )
        external
        view
        returns (uint128[] memory accountsIds);

    /// @dev Returns the maximum amount that can be deposited as margin for a given
    /// collateral type.
    /// @param collateralType The address of the collateral type.
    /// @return marginCollateralConfiguration The configuration parameters of the given collateral type.
    function getMarginCollateralConfiguration(address collateralType)
        external
        view
        returns (MarginCollateralConfiguration.Data memory marginCollateralConfiguration);

    /// @notice Sets the address of the account token NFT contract.
    /// @param perpsAccountToken The account token address.
    function setPerpsAccountToken(address perpsAccountToken) external;

    /// @notice Sets the address of the Liquidity Engine contract.
    /// @param liquidityEngine The Liquidity Engine proxy address.
    function setLiquidityEngine(address liquidityEngine) external;

    /// @notice Configures the collateral priority.
    /// @param collateralTypes The array of collateral type addresses.
    function configureCollateralPriority(address[] calldata collateralTypes) external;

    /// @notice Configures the liquidators.
    /// @param liquidators The array of liquidator addresses.
    /// @param enable The array of boolean values that enable or disable the liquidator.
    function configureLiquidators(address[] calldata liquidators, bool[] calldata enable) external;

    /// @notice Configures the settings of a given margin collateral type.
    /// @param collateralType The address of the collateral type.
    /// @param depositCap The maximum amount of collateral that can be deposited.
    /// @param loanToValue The value used to calculate the effective margin balance of a given collateral type.
    /// @param priceFeed The price oracle address.
    function configureMarginCollateral(
        address collateralType,
        uint128 depositCap,
        uint120 loanToValue,
        address priceFeed
    )
        external;

    /// @notice Removes the given collateral type from the collateral priority.
    /// @param collateralType The address of the collateral type to remove.
    function removeCollateralFromPriorityList(address collateralType) external;

    /// @notice Configures the system parameters.
    /// @param maxPositionsPerAccount The maximum number of open positions per account.
    /// @param marketOrderMaxLifetime The maximum lifetime of a market order to be considered active.
    /// @param liquidationFeeUsdX18 The liquidation fee in USD.
    function configureSystemParameters(
        uint128 maxPositionsPerAccount,
        uint128 marketOrderMaxLifetime,
        uint128 liquidationFeeUsdX18
    )
        external;

    /// @notice `createPerpMarket` function parameters.
    /// @param marketId The perps market id.
    /// @param name The perps market name.
    /// @param symbol The perps market symbol.
    /// @param priceAdapter The price adapter contract, which handles the market's index price.
    /// @param initialMarginRateX18 The perps market min initial margin rate, which defines the max leverage.
    /// @param maintenanceMarginRateX18 The perps market maintenance margin rate.
    /// @param maxOpenInterest The perps market maximum open interest per side.
    /// @param maxFundingVelocity The perps market maximum funding rate velocity.
    /// @param skewScale The configuration parameter used to scale the market's price impact and funding rate.
    /// @param minTradeSizeX18 The minimum size of a trade in contract units.
    /// @param marketOrderConfiguration The perps market settlement configuration.
    /// @param orderFees The perps market maker and taker fees.
    struct CreatePerpMarketParams {
        uint128 marketId;
        string name;
        string symbol;
        address priceAdapter;
        uint128 initialMarginRateX18;
        uint128 maintenanceMarginRateX18;
        uint128 maxOpenInterest;
        uint128 maxFundingVelocity;
        uint256 skewScale;
        uint256 minTradeSizeX18;
        SettlementConfiguration.Data marketOrderConfiguration;
        SettlementConfiguration.Data[] customOrderStrategies;
        OrderFees.Data orderFees;
    }

    /// @notice Creates a new market with the requested market id.
    /// @dev See {CreatePerpMarketParams}.
    function createPerpMarket(CreatePerpMarketParams calldata params) external;

    /// @notice `updatePerpMarketConfiguration` params.
    /// @param marketId The perp market id.
    /// @param name The perp market name.
    /// @param symbol The perp market symbol.
    /// @param priceAdapter The price adapter contract, which handles the market's index price.
    /// @param initialMarginRateX18 The perp market min initial margin rate, which defines the max leverage.
    /// @param maintenanceMarginRateX18 The perp market maintenance margin rate.
    /// @param maxOpenInterest The perp market maximum open interest per side.
    /// @param maxFundingVelocity The perp market maximum funding rate velocity.
    /// @param skewScale The configuration parameter used to scale the market's price impact and funding rate.
    /// @param minTradeSizeX18 The minimum size of a trade in contract units.
    /// @param orderFees The perp market maker and taker fees.
    struct UpdatePerpMarketConfigurationParams {
        uint128 marketId;
        string name;
        string symbol;
        address priceAdapter;
        uint128 initialMarginRateX18;
        uint128 maintenanceMarginRateX18;
        uint128 maxOpenInterest;
        uint128 maxFundingVelocity;
        uint256 skewScale;
        uint256 minTradeSizeX18;
        OrderFees.Data orderFees;
    }

    /// @notice Updates the configuration variables of the given perp market id.
    /// @dev A market's configuration must be updated with caution, as the update of some variables may directly
    /// impact open positions.
    /// @dev See {UpdatePerpMarketConfigurationParams}.
    function updatePerpMarketConfiguration(UpdatePerpMarketConfigurationParams calldata params) external;

    /// @notice Updates the settlement configuration of a given market.
    /// @param marketId The perp market id.
    /// @param settlementConfigurationId The perp market settlement configuration id.
    /// @param newSettlementConfiguration The new settlement configuration.
    function updateSettlementConfiguration(
        uint128 marketId,
        uint128 settlementConfigurationId,
        SettlementConfiguration.Data memory newSettlementConfiguration
    )
        external;
    /// @notice Enables or disabled the perp market of the given market id.
    /// @param marketId The perps market id.
    /// @param enable Whether the market should be enabled or disabled.
    function updatePerpMarketStatus(uint128 marketId, bool enable) external;
}
