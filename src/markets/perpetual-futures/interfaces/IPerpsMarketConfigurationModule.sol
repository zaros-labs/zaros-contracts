// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface IPerpsMarketConfigurationModule {
    function setZaros(address zaros) external;

    function setUsd(address zrsUsd) external;

    function registerMarket(address perpsMarket) external;
}
