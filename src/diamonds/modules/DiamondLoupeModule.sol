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
        _addInterface(type(IDiamondLoupe).interfaceId);
        _addInterface(type(IERC165).interfaceId);
    }

    function facetSelectors(address facet) external view returns (bytes4[] memory selectors) {
        EnumerableSet.Bytes32Set storage facetSelectors_ = DiamondCut.load().facetSelectors[facet];
        uint256 selectorCount = facetSelectors_.length();
        selectors = new bytes4[](selectorCount);
        for (uint256 i = 0; i < selectorCount; i++) {
            selectors[i] = bytes4(facetSelectors_.at(i));
        }
    }

    function facetAddresses() external view returns (address[] memory) {
        return DiamondCut.load().facets.values();
    }

    function facetAddress(bytes4 selector) external view returns (address) {
        return DiamondCut.load().selectorToFacet[selector];
    }

    function facets() external view returns (Facet[] memory facets) {
        address[] memory facetAddresses = _facetAddresses();
        uint256 facetCount = facetAddresses.length;
        facets = new Facet[](facetCount);

        // Build up facet struct.
        for (uint256 i = 0; i < facetCount; i++) {
            address facet = facetAddresses[i];
            bytes4[] memory selectors = _facetSelectors(facet);

            facets[i] = Facet({ facet: facet, selectors: selectors });
        }
    }

    function supportsInterface(bytes4 interfaceId) external view returns (bool) {
        return DiamondLoupe.load().supportedInterfaces[interfaceId];
    }

    function _addInterface(bytes4 interfaceId) internal {
        DiamondLoupe.load().supportedInterfaces[interfaceId] = true;
    }

    function _removeInterface(bytes4 interfaceId) internal {
        DiamondLoupe.load().supportedInterfaces[interfaceId] = false;
    }
}
