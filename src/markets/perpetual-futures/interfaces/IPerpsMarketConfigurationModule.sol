// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface IPerpsMarketConfigurationModule {
    event LogSetSupportedMarket(address indexed perpsMarket, bool enabled);

    event LogSetSupportedCollateral(address indexed sender, address indexed collateralType, bool enabled);

    function setZaros(address zaros) external;

    function setUsd(address zrsUsd) external;

    function setSupportedMarket(address perpsMarket, bool enable) external;

    function setSupportedCollateral(address collateralType, bool enabled) external;
}
