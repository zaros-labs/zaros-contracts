// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { OrderFees } from "../storage/OrderFees.sol";

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
    event LogCreatePerpsMarket(uint128 indexed marketId, string name, string symbol);

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

    /// @notice Updates the CL Automation forwarder address and the Data Streams verifier address.
    /// @param chainlinkForwarder The address of the Chainlink Automation forwarder.
    /// @param chainlinkVerifier The address of the Chainlink Data Streams verifier.
    function setChainlinkAddresses(address chainlinkForwarder, address chainlinkVerifier) external;

    /// @notice Creates a new market with the requested market id.
    /// @param marketId The perps market id.
    /// @param name The perps market name.
    /// @param symbol The perps market symbol.
    /// @param streamId The chainlink data streams feed id.
    /// @param priceFeed The perps market price feed address.
    /// @param maintenanceMarginRate The perps market maintenance margin rate.
    /// @param maxOpenInterest The perps market maximum open interest per side.
    /// @param minInitialMarginRate The perps market min initial margin rate, which defines the max leverage.
    /// @param orderFees The perps market maker and taker fees.
    function createPerpsMarket(
        uint128 marketId,
        string calldata name,
        string calldata symbol,
        string calldata streamId,
        address priceFeed,
        uint128 maintenanceMarginRate,
        uint128 maxOpenInterest,
        uint128 minInitialMarginRate,
        OrderFees.Data calldata orderFees
    )
        external;
}
