// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

/**
 * @title IDiamond
 * @notice Interface of the Diamond Proxy contract. See [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535).
 */
interface IDiamond {
    /**
     * @notice Expresses the action of adding, replacing, or removing a facet.
     */
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    /**
     * @dev Describes a facet to be added, replaced or removed.
     * @param facet Address of the facet, that contains the functions.
     * @param action The action to be performed.
     * @param selectors The function selectors of the facet to be cut.
     */
    struct FacetCut {
        address facet;
        FacetCutAction action;
        bytes4[] selectors;
    }

    struct InitParams {
        FacetCut[] baseFacets;
        address[] initializables;
        bytes[] initializePayloads;
    }
}
