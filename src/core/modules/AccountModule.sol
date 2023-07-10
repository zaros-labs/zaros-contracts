// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Zaros dependencies
import { IAccountModule } from "../interfaces/IAccountModule.sol";
import { IAccountTokenModule } from "../interfaces/IAccountTokenModule.sol";
import { Account } from "../storage/Account.sol";
import { AccountRBAC } from "../storage/AccountRBAC.sol";
import { FeatureFlag } from "../../utils/storage/FeatureFlag.sol";
import { SystemAccountConfiguration } from "../storage/SystemAccountConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

contract AccountModule is IAccountModule {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using AccountRBAC for AccountRBAC.Data;
    using Account for Account.Data;

    bytes32 private constant _ACCOUNT_SYSTEM = "accountNft";

    bytes32 private constant _CREATE_ACCOUNT_FEATURE_FLAG = "createAccount";

    /**
     * @inheritdoc IAccountModule
     */
    function getAccountTokenAddress() public view override returns (address) {
        return SystemAccountConfiguration.load().accountToken;
    }

    /**
     * @inheritdoc IAccountModule
     */
    function getAccountPermissions(uint128 accountId)
        external
        view
        returns (AccountPermissions[] memory accountPerms)
    {
        AccountRBAC.Data storage accountRbac = Account.load(accountId).rbac;

        uint256 allPermissionsLength = accountRbac.permissionAddresses.length();
        accountPerms = new AccountPermissions[](allPermissionsLength);
        for (uint256 i = 1; i <= allPermissionsLength; i++) {
            address permissionAddress = accountRbac.permissionAddresses.at(i);
            accountPerms[i - 1] = AccountPermissions({
                user: permissionAddress,
                permissions: accountRbac.permissions[permissionAddress].values()
            });
        }
    }

    /**
     * @inheritdoc IAccountModule
     */
    function createAccount() external override {
        FeatureFlag.ensureAccessToFeature(_CREATE_ACCOUNT_FEATURE_FLAG);
        (uint128 accountId, IAccountTokenModule accountTokenModule) = SystemAccountConfiguration.onCreateAccount();
        accountTokenModule.mint(msg.sender, accountId);

        Account.create(accountId, msg.sender);

        emit LogCreateAccount(accountId, msg.sender);
    }

    /**
     * @inheritdoc IAccountModule
     */
    function notifyAccountTransfer(address to, uint128 accountId) external override {
        _onlyAccountToken();

        Account.Data storage account = Account.load(accountId);

        address[] memory permissionedAddresses = account.rbac.permissionAddresses.values();
        for (uint256 i = 0; i < permissionedAddresses.length; i++) {
            account.rbac.revokeAllPermissions(permissionedAddresses[i]);
        }

        account.rbac.setOwner(to);
    }

    /**
     * @inheritdoc IAccountModule
     */
    function hasPermission(uint128 accountId, bytes32 permission, address user) public view override returns (bool) {
        return Account.load(accountId).rbac.hasPermission(permission, user);
    }

    /**
     * @inheritdoc IAccountModule
     */
    function isAuthorized(uint128 accountId, bytes32 permission, address user) public view override returns (bool) {
        return Account.load(accountId).rbac.authorized(permission, user);
    }

    /**
     * @inheritdoc IAccountModule
     */
    function grantPermission(uint128 accountId, bytes32 permission, address user) external override {
        AccountRBAC.isPermissionValid(permission);

        Account.Data storage account =
            Account.loadAccountAndValidatePermission(accountId, AccountRBAC._ADMIN_PERMISSION);

        account.rbac.grantPermission(permission, user);

        emit LogGrantPermission(accountId, permission, user, msg.sender);
    }

    /**
     * @inheritdoc IAccountModule
     */
    function revokePermission(uint128 accountId, bytes32 permission, address user) external override {
        Account.Data storage account =
            Account.loadAccountAndValidatePermission(accountId, AccountRBAC._ADMIN_PERMISSION);

        account.rbac.revokePermission(permission, user);

        emit LogRevokePermission(accountId, permission, user, msg.sender);
    }

    /**
     * @inheritdoc IAccountModule
     */
    function renouncePermission(uint128 accountId, bytes32 permission) external override {
        if (!Account.load(accountId).rbac.hasPermission(permission, msg.sender)) {
            revert Zaros_AccountModule_PermissionNotGranted(accountId, permission, msg.sender);
        }

        Account.load(accountId).rbac.revokePermission(permission, msg.sender);

        emit LogRevokePermission(accountId, permission, msg.sender, msg.sender);
    }

    /**
     * @inheritdoc IAccountModule
     */
    function getAccountOwner(uint128 accountId) public view returns (address) {
        return Account.load(accountId).rbac.owner;
    }

    /**
     * @inheritdoc IAccountModule
     */
    function getAccountLastInteraction(uint128 accountId) external view returns (uint256) {
        return Account.load(accountId).lastInteraction;
    }

    /**
     * @dev Reverts if the caller is not the account token managed by this module.
     */
    // Note: Disabling Solidity warning, not sure why it suggests pure mutability.
    // solc-ignore-next-line func-mutability
    function _onlyAccountToken() internal view {
        if (msg.sender != address(getAccountTokenAddress())) {
            revert Zaros_AccountModule_OnlyAccountTokenProxy(msg.sender);
        }
    }
}
