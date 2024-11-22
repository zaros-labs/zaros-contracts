// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface ICurvePool {
    function coins(uint256 index) external view returns (address);
    function nCoins() external view returns (uint256);
}
