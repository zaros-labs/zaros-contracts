//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Zaros dependencies
import { AddressError } from "../../utils/Errors.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

library AccountRBAC {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 internal constant _ADMIN_PERMISSION = "ADMIN";
    bytes32 internal constant _WITHDRAW_PERMISSION = "WITHDRAW";
    bytes32 internal constant _DELEGATE_PERMISSION = "DELEGATE";
    bytes32 internal constant _MINT_PERMISSION = "MINT";
    bytes32 internal constant _REWARDS_PERMISSION = "REWARDS";

    error Zaros_AccountRBAC_InvalidPermission(bytes32 permission);

    struct Data {
        address owner;
        mapping(address operator => EnumerableSet.Bytes32Set) permissions;
        EnumerableSet.AddressSet permissionAddresses;
    }

    function isPermissionValid(bytes32 permission) internal pure {
        if (
            permission != AccountRBAC._WITHDRAW_PERMISSION && permission != AccountRBAC._DELEGATE_PERMISSION
                && permission != AccountRBAC._MINT_PERMISSION && permission != AccountRBAC._ADMIN_PERMISSION
                && permission != AccountRBAC._REWARDS_PERMISSION
        ) {
            revert Zaros_AccountRBAC_InvalidPermission(permission);
        }
    }

    function setOwner(Data storage self, address owner) internal {
        self.owner = owner;
    }

    function grantPermission(Data storage self, bytes32 permission, address target) internal {
        if (target == address(0)) {
            revert AddressError.Zaros_ZeroAddress();
        }

        if (permission == "") {
            revert Zaros_AccountRBAC_InvalidPermission("");
        }

        if (!self.permissionAddresses.contains(target)) {
            self.permissionAddresses.add(target);
        }

        self.permissions[target].add(permission);
    }

    function revokePermission(Data storage self, bytes32 permission, address target) internal {
        self.permissions[target].remove(permission);

        if (self.permissions[target].length() == 0) {
            self.permissionAddresses.remove(target);
        }
    }

    function revokeAllPermissions(Data storage self, address target) internal {
        bytes32[] memory permissions = self.permissions[target].values();

        if (permissions.length == 0) {
            return;
        }

        for (uint256 i = 0; i < permissions.length; i++) {
            self.permissions[target].remove(permissions[i]);
        }

        self.permissionAddresses.remove(target);
    }

    function hasPermission(Data storage self, bytes32 permission, address target) internal view returns (bool) {
        return target != address(0) && self.permissions[target].contains(permission);
    }

    function authorized(Data storage self, bytes32 permission, address target) internal view returns (bool) {
        return (
            (target == self.owner) || hasPermission(self, _ADMIN_PERMISSION, target)
                || hasPermission(self, permission, target)
        );
    }
}
