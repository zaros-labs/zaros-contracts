// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

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

    /// @dev TODO: support perps engine
    // function setSupportedMarket(address perpsMarket, bool enable) external;

    /// @notice Enables or disables the given collateral type.
    /// @param collateralType The address of the collateral type.
    /// @param shouldEnable `true` if the collateral type should be enabled, `false` if it should be disabled.
    function setIsCollateralEnabled(address collateralType, bool shouldEnable) external;
}
