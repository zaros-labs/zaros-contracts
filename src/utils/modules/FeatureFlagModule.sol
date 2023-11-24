// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IFeatureFlagModule } from "../interfaces/IFeatureFlagModule.sol";
import { FeatureFlag } from "../storage/FeatureFlag.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { Ownable } from "@openzeppelin/access/Ownable.sol";

abstract contract FeatureFlagModule is IFeatureFlagModule, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using FeatureFlag for FeatureFlag.Data;

    function setFeatureFlagAllowAll(bytes32 feature, bool allowAll) external override onlyOwner {
        FeatureFlag.load(feature).allowAll = allowAll;

        if (allowAll) {
            FeatureFlag.load(feature).denyAll = false;
        }

        emit FeatureFlagAllowAllSet(feature, allowAll);
    }

    function setFeatureFlagDenyAll(bytes32 feature, bool denyAll) external override {
        FeatureFlag.Data storage flag = FeatureFlag.load(feature);

        if (!denyAll || !flag.isDenier(msg.sender)) {
            _checkOwner();
        }

        flag.denyAll = denyAll;

        emit FeatureFlagDenyAllSet(feature, denyAll);
    }

    function addToFeatureFlagAllowlist(bytes32 feature, address account) external override onlyOwner {
        EnumerableSet.AddressSet storage permissionedAddresses = FeatureFlag.load(feature).permissionedAddresses;

        if (!permissionedAddresses.contains(account)) {
            permissionedAddresses.add(account);
            emit FeatureFlagAllowlistAdded(feature, account);
        }
    }

    function removeFromFeatureFlagAllowlist(bytes32 feature, address account) external override onlyOwner {
        EnumerableSet.AddressSet storage permissionedAddresses = FeatureFlag.load(feature).permissionedAddresses;

        if (permissionedAddresses.contains(account)) {
            FeatureFlag.load(feature).permissionedAddresses.remove(account);
            emit FeatureFlagAllowlistRemoved(feature, account);
        }
    }

    function setDeniers(bytes32 feature, address[] memory deniers) external override onlyOwner {
        FeatureFlag.Data storage flag = FeatureFlag.load(feature);

        // resize array (its really dumb how you have to do this)
        uint256 storageLen = flag.deniers.length;
        for (uint256 i = storageLen; i > deniers.length; i--) {
            flag.deniers.pop();
        }

        for (uint256 i = 0; i < deniers.length; i++) {
            if (i >= storageLen) {
                flag.deniers.push(deniers[i]);
            } else {
                flag.deniers[i] = deniers[i];
            }
        }

        emit FeatureFlagDeniersReset(feature, deniers);
    }

    function getDeniers(bytes32 feature) external view override returns (address[] memory) {
        FeatureFlag.Data storage flag = FeatureFlag.load(feature);
        address[] memory addrs = new address[](flag.deniers.length);
        for (uint256 i = 0; i < addrs.length; i++) {
            addrs[i] = flag.deniers[i];
        }

        return addrs;
    }

    function getFeatureFlagAllowAll(bytes32 feature) external view override returns (bool) {
        return FeatureFlag.load(feature).allowAll;
    }

    function getFeatureFlagDenyAll(bytes32 feature) external view override returns (bool) {
        return FeatureFlag.load(feature).denyAll;
    }

    function getFeatureFlagAllowlist(bytes32 feature) external view override returns (address[] memory) {
        return FeatureFlag.load(feature).permissionedAddresses.values();
    }

    function isFeatureAllowed(bytes32 feature, address account) external view override returns (bool) {
        return FeatureFlag.hasAccess(feature, account);
    }
}
