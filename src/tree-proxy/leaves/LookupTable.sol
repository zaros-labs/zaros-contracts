// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

library LookupTable {
    bytes32 internal constant DIAMOND_LOUPE_STORAGE = keccak256("fi.zaros.tree-proxy.LookupTable");

    struct Data {
        mapping(bytes4 interfaceId => bool isSupported) supportedInterfaces;
    }

    function load() internal pure returns (Data storage lookupTable) {
        bytes32 position = DIAMOND_LOUPE_STORAGE;

        assembly {
            lookupTable.slot := position
        }
    }

    function addInterface(Data storage self, bytes4 interfaceId) internal {
        self.supportedInterfaces[interfaceId] = true;
    }

    function removeInterface(Data storage self, bytes4 interfaceId) internal {
        self.supportedInterfaces[interfaceId] = false;
    }
}
