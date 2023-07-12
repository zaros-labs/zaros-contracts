// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface IStrategy {
    function name() external returns (string memory);

    function token() external returns (address);

    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function withdrawAll() external;

    function balanceOf() external view returns (uint256);

    function balanceOfToken() external view returns (uint256);

    function balanceOfPool() external view returns (uint256);

    function getExchangeRate() external view returns (uint256);

    function harvest() external;

    function retireStrat() external;

    function panic() external;

    function pause() external;

    function unpause() external;

    function paused() external view returns (bool);
}
