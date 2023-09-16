// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { OrderFees } from "../storage/OrderFees.sol";

interface IPerpsConfigurationModule {
    /// @notice Thrown when the provided `accountToken` is the zero address.
    error Zaros_PerpsConfigurationModule_PerpsAccountTokenNotDefined();
    /// @notice Thrown when the provided `zaros` is the zero address.
    error Zaros_PerpsConfigurationModule_ZarosNotDefined();

    /// @notice Emitted when a new collateral type is enabled or disabled.
    /// @param sender The address that enabled or disabled the collateral type.
    /// @param collateralType The address of the collateral type.
    /// @param enabled `true` if the collateral type was enabled, `false` if it was disabled.
    event LogSetSupportedCollateral(address indexed sender, address indexed collateralType, bool enabled);

    /// @notice Emitted when a new perps market is created.
    /// @param marketId The perps market id.
    /// @param name The perps market name.
    /// @param symbol The perps market symbol.
    event LogCreatePerpsMarket(uint128 indexed marketId, string name, string symbol);

    /// @notice Returns whether the given collateral type is enabled or not.
    /// @param collateralType The address of the collateral type.
    /// @return enabled `true` if the collateral type is enabled, `false` otherwise.
    function isCollateralEnabled(address collateralType) external view returns (bool enabled);

    /// @notice Sets the address of the account token NFT contract.
    /// @param perpsAccountToken The account token address.
    function setPerpsAccountToken(address perpsAccountToken) external;

    /// @notice Sets the address of the Zaros core contract.
    /// @param zaros The Zaros core address.
    function setZaros(address zaros) external;

    /// @notice Enables or disables the given collateral type.
    /// @param collateralType The address of the collateral type.
    /// @param shouldEnable `true` if the collateral type should be enabled, `false` if it should be disabled.
    function setIsCollateralEnabled(address collateralType, bool shouldEnable) external;

    /// @notice Creates a new market with the requested market id.
    /// @param marketId The perps market id.
    /// @param name The perps market name.
    /// @param symbol The perps market symbol.
    /// @param priceFeed The perps market price feed address.
    /// @param maxLeverage The perps market max leverage.
    /// @param orderFees The perps market maker and taker fees.
    /// @param maxOpenInterest The perps market maximum open interest per side.
    function createPerpsMarket(
        uint128 marketId,
        string calldata name,
        string calldata symbol,
        address priceFeed,
        uint128 maxLeverage,
        uint256 maxOpenInterest,
        OrderFees.Data calldata orderFees
    )
        external;
}
