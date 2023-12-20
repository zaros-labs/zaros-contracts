// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { OrderFees } from "../storage/OrderFees.sol";
import { SettlementConfiguration } from "../storage/SettlementConfiguration.sol";

/// @title Perps Configuration Module.
/// @notice This module is used by the protocol controller to configure the perps
/// exchange system.
interface IPerpsConfigurationModule {
    /// @notice Emitted when a new collateral type is enabled or disabled.
    /// @param sender The address that enabled or disabled the collateral type.
    /// @param collateralType The address of the collateral type.
    /// @param depositCap The maximum amount of collateral that can be deposited.
    /// @param decimals The amount of decimals of the collateral type's ERC20 token.
    /// @param priceFeed The price oracle address.
    event LogConfigureCollateral(
        address indexed sender, address indexed collateralType, uint248 depositCap, uint8 decimals, address priceFeed
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
    event LogCreatePerpsMarket(
        uint128 indexed marketId,
        string name,
        string symbol,
        uint128 maintenanceMarginRate,
        uint128 maxOpenInterest,
        uint128 minInitialMarginRate,
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
    function getDepositCapForMarginCollateral(address collateralType) external view returns (uint256 depositCap);

    /// @notice Sets the address of the account token NFT contract.
    /// @param perpsAccountToken The account token address.
    function setPerpsAccountToken(address perpsAccountToken) external;

    /// @notice Sets the address of the Liquidity Engine contract.
    /// @param liquidityEngine The Liquidity Engine proxy address.
    function setLiquidityEngine(address liquidityEngine) external;

    /// @notice Configures the settings of a given margin collateral type.
    /// @param collateralType The address of the collateral type.
    /// @param depositCap The maximum amount of collateral that can be deposited.
    /// @param priceFeed The price oracle address.
    function configureMarginCollateral(address collateralType, uint248 depositCap, address priceFeed) external;

    /// @notice Configures the system parameters.
    /// @param maxPositionsPerAccount The maximum number of open positions per account.
    /// @param marketOrderMaxLifetime The maximum lifetime of a market order to be considered active.
    function configureSystemParameters(uint128 maxPositionsPerAccount, uint128 marketOrderMaxLifetime) external;

    /// @notice Creates a new market with the requested market id.
    /// @param marketId The perps market id.
    /// @param name The perps market name.
    /// @param symbol The perps market symbol.
    /// @param maintenanceMarginRate The perps market maintenance margin rate.
    /// @param maxOpenInterest The perps market maximum open interest per side.
    /// @param minInitialMarginRate The perps market min initial margin rate, which defines the max leverage.
    /// @param marketOrderStrategy The perps market settlement strategy.
    /// @param orderFees The perps market maker and taker fees.
    function createPerpsMarket(
        uint128 marketId,
        string calldata name,
        string calldata symbol,
        uint128 maintenanceMarginRate,
        uint128 maxOpenInterest,
        uint128 minInitialMarginRate,
        SettlementConfiguration.Data calldata marketOrderStrategy,
        SettlementConfiguration.Data[] calldata customTriggerStrategies,
        OrderFees.Data calldata orderFees
    )
        external;

    function updatePerpMarketStatus(uint128 marketId, bool enable) external;
}
