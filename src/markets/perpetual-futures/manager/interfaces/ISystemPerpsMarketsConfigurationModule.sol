// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface ISystemPerpsMarketsConfigurationModule {
    error Zaros_SystemPerpsMarketsConfigurationModule_AccountTokenNotDefined();
    error Zaros_SystemPerpsMarketsConfigurationModule_ZarosNotDefined();

    event LogSetSupportedMarket(address indexed perpsMarket, bool enabled);
    event LogSetSupportedCollateral(address indexed sender, address indexed collateralType, bool enabled);

    function isCollateralEnabled(address collateralType) external view returns (bool);

    function setAccountToken(address accountToken) external;

    function setZaros(address zaros) external;

    // function setSupportedMarket(address perpsMarket, bool enable) external;

    function setIsEnabledCollateral(address collateralType, bool shouldEnable) external;
}
