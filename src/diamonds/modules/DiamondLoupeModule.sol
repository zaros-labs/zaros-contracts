// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { DiamondCut } from "../storage/DiamondCut.sol";
import { IDiamondLoupeModule } from "../interfaces/IDiamondLoupeModule.sol";
import { DiamondLoupe } from "../storage/DiamondLoupe.sol";

// Open Zeppelin Upgradeable dependencies
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

abstract contract DiamondLoupeModule is IDiamondLoupeModule, Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    function DiamondLoupe_init() external onlyInitializing {
        DiamondLoupe.Data storage diamondLoupe = DiamondLoupe.load();

        diamondLoupe.addInterface(type(IDiamondLoupe).interfaceId);
        diamondLoupe.addInterface(type(IERC165).interfaceId);
    }

    function facetSelectors(address facet) external view returns (bytes4[] memory) {
        DiamondCut storage diamondCut = DiamondCut.load();

        return diamondCut.getFacetSelectors(facet);
    }

    function facetAddresses() external view returns (address[] memory) {
        DiamondCut storage diamondCut = DiamondCut.load();

        return diamondCut.getFacetAddresses();
    }

    function facetAddress(bytes4 selector) external view returns (address) {
        return DiamondCut.load().selectorToFacet[selector];
    }

    function facets() external view returns (Facet[] memory) {
        DiamondCut storage diamondCut = DiamondCut.load();

        return diamondCut.getFacets();
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return DiamondLoupe.load().supportedInterfaces[interfaceId];
    }
}
