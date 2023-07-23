//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IAccountModule {
    error Zaros_AccountModule_OnlyAccountTokenProxy(address origin);

    error Zaros_AccountModule_PermissionNotGranted(uint128 accountId, bytes32 permission, address user);

    event LogCreateAccount(uint128 indexed accountId, address indexed owner);

    event LogGrantPermission(
        uint128 indexed accountId, bytes32 indexed permission, address indexed user, address sender
    );

    event LogRevokePermission(
        uint128 indexed accountId, bytes32 indexed permission, address indexed user, address sender
    );

    // struct AccountPermissions {
    //     address user;
    //     bytes32[] permissions;
    // }

    // function getAccountPermissions(uint128 accountId)
    //     external
    //     view
    //     returns (AccountPermissions[] memory accountPerms);

    // function hasPermission(
    //     uint128 accountId,
    //     bytes32 permission,
    //     address user
    // )
    //     external
    //     view
    //     returns (bool hasPermission);

    // function isAuthorized(
    //     uint128 accountId,
    //     bytes32 permission,
    //     address target
    // )
    //     external
    //     view
    //     returns (bool isAuthorized);

    function getAccountTokenAddress() external view returns (address accountNftToken);

    function getAccountOwner(uint128 accountId) external view returns (address owner);

    // function getAccountLastInteraction(uint128 accountId) external view returns (uint256 timestamp);

    function createAccount() external returns (uint128 accountId);

    function createAccountAndMulticall(bytes[] calldata data) external payable returns (bytes[] memory results);

    function notifyAccountTransfer(address to, uint128 accountId) external;
}
