// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface IStrategyManagerModule {
    function registerStrategy(address strategy, address collateralType) external;
}
