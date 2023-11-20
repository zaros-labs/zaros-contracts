// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

interface IMulticallModule {
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}
