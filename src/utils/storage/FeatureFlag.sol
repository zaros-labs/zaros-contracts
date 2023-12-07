//SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

library FeatureFlag {
    using EnumerableSet for EnumerableSet.AddressSet;

    error Zaros_FeatureFlag_FeatureUnavailable(bytes32 which);

    struct Data {
        bytes32 name;
        bool allowAll;
        bool denyAll;
        EnumerableSet.AddressSet permissionedAddresses;
        address[] deniers;
    }

    string internal constant FEATURE_FLAG_DOMAIN = "fi.liquidityEngine.utils.FeatureFlag";

    function load(bytes32 featureName) internal pure returns (Data storage store) {
        bytes32 s = keccak256(abi.encode(FEATURE_FLAG_DOMAIN, featureName));
        assembly {
            store.slot := s
        }
    }

    function ensureAccessToFeature(bytes32 feature) internal view {
        if (!hasAccess(feature, msg.sender)) {
            revert Zaros_FeatureFlag_FeatureUnavailable(feature);
        }
    }

    function hasAccess(bytes32 feature, address value) internal view returns (bool) {
        Data storage store = FeatureFlag.load(feature);

        if (store.denyAll) {
            return false;
        }

        return store.allowAll || store.permissionedAddresses.contains(value);
    }

    function isDenier(Data storage self, address possibleDenier) internal view returns (bool) {
        for (uint256 i = 0; i < self.deniers.length; i++) {
            if (self.deniers[i] == possibleDenier) {
                return true;
            }
        }

        return false;
    }
}
