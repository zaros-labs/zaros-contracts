// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface ISystemPerpsMarketsConfigurationModule {
    event LogSetSupportedMarket(address indexed perpsMarket, bool enabled);

    event LogSetSupportedCollateral(address indexed sender, address indexed collateralType, bool enabled);

    function zaros() external view returns (address);

    function accountToken() external view returns (address);

    function isCollateralEnabled(address collateralType) external view returns (bool);

    function setZaros(address zaros) external;

    function setUsd(address zrsUsd) external;

    function setSupportedMarket(address perpsMarket, bool enable) external;

    function setIsEnabledCollateral(address collateralType, bool shouldEnable) external;
}
