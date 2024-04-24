// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IRootProxy } from "../interfaces/IRootProxy.sol";
import { IDiamondCutModule } from "../interfaces/IDiamondCutModule.sol";
import { DiamondCut } from "../storage/DiamondCut.sol";
import { Facet } from "../storage/Facet.sol";

// Open Zeppelin dependencies
import { Address } from "@openzeppelin/utils/Address.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

library DiamondCut {
    using EnumerableSet for *;

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

    function validateFacetCut(IRootProxy.FacetCut memory facetCut) internal view {
        if (uint256(facetCut.action) > 2) {
            revert Errors.IncorrectFacetCutAction();
        }
        if (facetCut.facet == address(0)) {
            revert Errors.FacetIsZeroAddress();
        }
        if (facetCut.facet.code.length == 0) {
            revert Errors.FacetIsNotContract(facetCut.facet);
        }
        if (facetCut.selectors.length == 0) {
            revert Errors.SelectorArrayEmpty(facetCut.facet);
        }
    }

    function getFacetAddress(Data storage self, bytes4 functionSelector) internal view returns (address facet) {
        facet = self.selectorToFacet[functionSelector];
    }

    function getFacetAddresses(Data storage self) internal view returns (address[] memory facetAddresses) {
        facetAddresses = self.facets.values();
    }

    function getFacetSelectors(Data storage self, address facet) internal view returns (bytes4[] memory selectors) {
        EnumerableSet.Bytes32Set storage facetSelectors_ = self.facetSelectors[facet];
        uint256 selectorCount = facetSelectors_.length();
        selectors = new bytes4[](selectorCount);
        for (uint256 i = 0; i < selectorCount; i++) {
            selectors[i] = bytes4(facetSelectors_.at(i));
        }
    }

    function getFacets(Data storage self) internal view returns (Facet.Data[] memory facets) {
        address[] memory facetAddresses = getFacetAddresses(self);
        uint256 facetCount = facetAddresses.length;
        facets = new Facet.Data[](facetCount);

        // Build up facet struct.
        for (uint256 i = 0; i < facetCount; i++) {
            address facet = facetAddresses[i];
            bytes4[] memory selectors = getFacetSelectors(self, facet);

            facets[i] = Facet.Data({ facet: facet, selectors: selectors });
        }
    }

    function updateModules(
        Data storage self,
        IRootProxy.FacetCut[] memory facetCuts,
        address[] memory initializables,
        bytes[] memory initializePayloads
    )
        internal
    {
        for (uint256 i = 0; i < facetCuts.length; i++) {
            IRootProxy.FacetCut memory facetCut = facetCuts[i];

            validateFacetCut(facetCut);

            if (facetCut.action == IRootProxy.FacetCutAction.Add) {
                addFacet(self, facetCut.facet, facetCut.selectors);
            } else if (facetCut.action == IRootProxy.FacetCutAction.Replace) {
                replaceFacet(self, facetCut.facet, facetCut.selectors);
            } else if (facetCut.action == IRootProxy.FacetCutAction.Remove) {
                removeFacet(self, facetCut.facet, facetCut.selectors);
            }
        }

        initializeDiamondCut(facetCuts, initializables, initializePayloads);
    }

    function addFacet(Data storage self, address facet, bytes4[] memory selectors) internal {
        // slither-disable-next-line unused-return
        self.facets.add(facet);
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 selector = selectors[i];

            if (selector == bytes4(0)) {
                revert Errors.SelectorIsZero();
            }
            if (self.selectorToFacet[selector] != address(0)) {
                revert Errors.FunctionAlreadyExists(selector);
            }

            self.selectorToFacet[selector] = facet;
            // slither-disable-next-line unused-return
            self.facetSelectors[facet].add(selector);
        }
    }

    function replaceFacet(Data storage self, address facet, bytes4[] memory selectors) internal {
        // slither-disable-next-line unused-return
        self.facets.add(facet);
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 selector = selectors[i];
            address oldFacet = self.selectorToFacet[selector];

            if (selector == bytes4(0)) {
                revert Errors.SelectorIsZero();
            }
            if (oldFacet == address(this)) {
                revert Errors.ImmutableFacet();
            }
            if (oldFacet == facet) {
                revert Errors.FunctionFromSameFacet(selector);
            }
            if (oldFacet == address(0)) {
                revert Errors.NonExistingFunction(selector);
            }

            // overwrite selector to new facet
            self.selectorToFacet[selector] = facet;

            // slither-disable-next-line unused-return
            self.facetSelectors[facet].add(selector);

            // slither-disable-next-line unused-return
            self.facetSelectors[oldFacet].remove(selector);

            // if no more selectors, remove old facet address
            if (self.facetSelectors[oldFacet].length() == 0) {
                // slither-disable-next-line unused-return
                self.facets.remove(oldFacet);
            }
        }
    }

    function removeFacet(Data storage self, address facet, bytes4[] memory selectors) internal {
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 selector = selectors[i];
            // also reverts if left side returns zero address
            if (selector == bytes4(0)) {
                revert Errors.SelectorIsZero();
            }
            if (facet == address(this)) {
                revert Errors.ImmutableFacet();
            }
            if (self.selectorToFacet[selector] != facet) {
                revert Errors.CannotRemoveFromOtherFacet(facet, selector);
            }

            delete self.selectorToFacet[selector];
            // slither-disable-next-line unused-return
            self.facetSelectors[facet].remove(selector);
            // if no more selectors in facet, remove facet address
            if (self.facetSelectors[facet].length() == 0) {
                // slither-disable-next-line unused-return
                self.facets.remove(facet);
            }
        }
    }

    function initializeDiamondCut(
        IRootProxy.FacetCut[] memory,
        address[] memory initializables,
        bytes[] memory initializePayloads
    )
        internal
    {
        for (uint256 i = 0; i < initializables.length; i++) {
            address initializable = initializables[i];
            bytes memory data = initializePayloads[i];

            if (initializable.code.length == 0) {
                revert Errors.InitializableIsNotContract(initializable);
            }

            Address.functionDelegateCall(initializable, data);
        }
    }
}
