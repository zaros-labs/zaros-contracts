//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IAccountModule {
    error Zaros_AccountModule_OnlyAccountToken(address origin);

    event LogCreateAccount(uint128 indexed accountId, address indexed owner);

    function getAccountTokenAddress() external view returns (address accountNftToken);

    function getAccountOwner(uint128 accountId) external view returns (address owner);

    function getAccountLastInteraction(uint128 accountId) external view returns (uint256 timestamp);

    function createAccount() external returns (uint128 accountId);

    function createAccountAndMulticall(bytes[] calldata data) external payable returns (bytes[] memory results);

    function notifyAccountTransfer(address to, uint128 accountId) external;
}
