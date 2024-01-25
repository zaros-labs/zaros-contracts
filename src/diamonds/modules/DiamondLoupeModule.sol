// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { DiamondCut } from "../storage/DiamondCut.sol";
import { IDiamondLoupeModule } from "../interfaces/IDiamondLoupeModule.sol";
import { DiamondLoupe } from "../storage/DiamondLoupe.sol";
import { Facet } from "../storage/Facet.sol";

// Open Zeppelin Upgradeable dependencies
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

contract DiamondLoupeModule is IDiamondLoupeModule, Initializable {
    using DiamondCut for DiamondCut.Data;
    using DiamondLoupe for DiamondLoupe.Data;
    using EnumerableSet for *;

    function facets() external view returns (Facet.Data[] memory) {
        DiamondCut.Data storage diamondCut = DiamondCut.load();

        return diamondCut.getFacets();
    }

    function facetFunctionSelectors(address facet) external view returns (bytes4[] memory) {
        DiamondCut.Data storage diamondCut = DiamondCut.load();

        return diamondCut.getFacetSelectors(facet);
    }

    function facetAddresses() external view returns (address[] memory) {
        DiamondCut.Data storage diamondCut = DiamondCut.load();

        return diamondCut.getFacetAddresses();
    }

    function facetAddress(bytes4 selector) external view returns (address) {
        DiamondCut.Data storage diamondCut = DiamondCut.load();

        return diamondCut.getFacetAddress(selector);
    }

    function facetSelectors(address facet) external view returns (bytes4[] memory) {
        DiamondCut.Data storage diamondCut = DiamondCut.load();

        return diamondCut.getFacetSelectors(facet);
    }
}
