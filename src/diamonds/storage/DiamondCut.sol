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

    function getFacetAddresses(Data storage self) internal view returns (address[] memory facetAddresses) {
        facetAddresses = self.facets.values();
    }

    function getFacetSelectors(Data storage self) internal view returns (bytes4[] memory selectors) {
        EnumerableSet.Bytes32Set storage facetSelectors_ = self.facetSelectors[facet];
        uint256 selectorCount = facetSelectors_.length();
        selectors = new bytes4[](selectorCount);
        for (uint256 i = 0; i < selectorCount; i++) {
            selectors[i] = bytes4(facetSelectors_.at(i));
        }
    }

    function getFacets(Data storage self) internal view returns (Facet[] memory facets) {
        address[] memory facetAddresses = getFacetAddresses(self);
        uint256 facetCount = facetAddresses.length;
        facets = new Facet[](facetCount);

        // Build up facet struct.
        for (uint256 i = 0; i < facetCount; i++) {
            address facet = facetAddresses[i];
            bytes4[] memory selectors = _facetSelectors(facet);

            facets[i] = Facet({ facet: facet, selectors: selectors });
        }
    }
}
