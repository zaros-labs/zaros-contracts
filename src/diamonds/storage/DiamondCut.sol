// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

library DiamondCut {
    bytes32 internal constant DIAMOND_CUT_STORAGE_POSITION = keccak256("fi.zaros.diamonds.DiamondCut");

    struct Data {
        EnumerableSet.AddressSet facets;
        mapping(bytes4 selector => address facet) selectorToFacet;
        mapping(address facet => EnumerableSet.Bytes32Set selectors) facetSelectors;
    }

    function load() internal pure returns (Data storage diamondCut) {
        bytes32 position = DIAMOND_CUT_STORAGE_POSITION;

        assembly {
            diamondCut.slot := position
        }
    }
}
