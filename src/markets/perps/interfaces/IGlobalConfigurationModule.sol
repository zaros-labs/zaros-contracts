// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { OrderFees } from "../storage/OrderFees.sol";
import { SettlementConfiguration } from "../storage/SettlementConfiguration.sol";

/// @notice `createPerpMarket` function parameters.
/// @param marketId The perps market id.
/// @param name The perps market name.
/// @param symbol The perps market symbol.
/// @param priceAdapter The price adapter contract, which stores onchain and outputs the market's index price.
/// @param minInitialMarginRateX18 The perps market min initial margin rate, which defines the max leverage.
/// @param maintenanceMarginRateX18 The perps market maintenance margin rate.
/// @param maxOpenInterest The perps market maximum open interest per side.
/// @param skewScale The configuration parameter used to scale the market's price impact and funding rate.
/// @param maxFundingVelocity The perps market maximum funding rate velocity.
/// @param marketOrderStrategy The perps market settlement strategy.
/// @param orderFees The perps market maker and taker fees.
struct CreatePerpMarketParams {
    uint128 marketId;
    string name;
    string symbol;
    address priceAdapter;
    uint128 minInitialMarginRateX18;
    uint128 maintenanceMarginRateX18;
    uint128 maxOpenInterest;
    uint256 skewScale;
    uint128 maxFundingVelocity;
    SettlementConfiguration.Data marketOrderStrategy;
    SettlementConfiguration.Data[] customTriggerStrategies;
    OrderFees.Data orderFees;
}

/// @title Global Configuration Module.
/// @notice This module is used by the protocol controller to configure the perps
/// exchange system.
interface IGlobalConfigurationModule {
    /// @notice Emitted when a new collateral type is enabled or disabled.
    /// @param sender The address that enabled or disabled the collateral type.
    /// @param collateralType The address of the collateral type.
    /// @param depositCap The maximum amount of collateral that can be deposited.
    /// @param decimals The amount of decimals of the collateral type's ERC20 token.
    /// @param priceFeed The price oracle address.
    event LogConfigureCollateral(
        address indexed sender, address indexed collateralType, uint128 depositCap, uint8 decimals, address priceFeed
    );

    /// @notice Emitted when a new price feed is configured for a collateral type.
    /// @param sender The address that configured the price feed.
    /// @param collateralType The address of the collateral type.
    /// @param priceFeed The address of the price feed.
    event LogConfigurePriceFeed(address indexed sender, address indexed collateralType, address priceFeed);

    /// @notice Emitted when a new perps market is created.
    /// @param marketId The perps market id.
    /// @param name The perps market name.
    /// @param symbol The perps market symbol.
    event LogCreatePerpMarket(
        uint128 indexed marketId,
        string name,
        string symbol,
        // TODO: uncomment
        // address priceAdapter,
        uint128 maintenanceMarginRateX18,
        uint128 maxOpenInterest,
        uint128 minInitialMarginRateX18,
        SettlementConfiguration.Data marketOrderStrategy,
        SettlementConfiguration.Data[] customTriggerStrategies,
        OrderFees.Data orderFees
    );

    /// @notice Emitted when a perp market is re-enabled by the owner.
    /// @param marketId The perps market id.
    event LogEnablePerpMarket(uint128 marketId);

    /// @notice Emitted when a perp market is disabled by the owner.
    /// @param marketId The perps market id.
    event LogDisablePerpMarket(uint128 marketId);

    /// @dev Returns the maximum amount that can be deposited as margin for a given
    /// collateral type.
    /// @param collateralType The address of the collateral type.
    /// @return depositCap The configured deposit cap for the given collateral type.
    function getDepositCapForMarginCollateralConfiguration(address collateralType)
        external
        view
        returns (uint256 depositCap);

    /// @notice Sets the address of the account token NFT contract.
    /// @param perpsAccountToken The account token address.
    function setPerpsAccountToken(address perpsAccountToken) external;

    /// @notice Sets the address of the Liquidity Engine contract.
    /// @param liquidityEngine The Liquidity Engine proxy address.
    function setLiquidityEngine(address liquidityEngine) external;

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

    /// @notice Configures the collateral priority.
    /// @param collateralTypes The array of collateral type addresses.
    function configureCollateralPriority(address[] calldata collateralTypes) external;

    /// @notice Removes the given collateral type from the collateral priority.
    /// @param collateralType The address of the collateral type to remove.
    function removeCollateralFromPriorityList(address collateralType) external;

    /// @notice Configures the system parameters.
    /// @param maxPositionsPerAccount The maximum number of open positions per account.
    /// @param marketOrderMaxLifetime The maximum lifetime of a market order to be considered active.
    function configureSystemParameters(uint128 maxPositionsPerAccount, uint128 marketOrderMaxLifetime) external;

    /// @notice Creates a new market with the requested market id.
    /// @dev See {CreatePerpMarketParams}.
    function createPerpMarket(CreatePerpMarketParams calldata params) external;

    /// @notice Enables or disabled the perp market of the given market id.
    /// @param marketId The perps market id.
    /// @param enable Whether the market should be enabled or disabled.
    function updatePerpMarketStatus(uint128 marketId, bool enable) external;
}
