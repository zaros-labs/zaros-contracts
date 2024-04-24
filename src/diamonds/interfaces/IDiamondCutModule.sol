// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IRootProxy } from "./IRootProxy.sol";

/**
 * @title IDiamondCut
 * @notice Interface of the DiamondCut facet. See [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535).
 */
interface IDiamondCutModule {
    /**
     * @notice Add/replace/remove any number of functions and optionally execute
     *         a function with delegatecall.
     * @param facetCuts Contains the facet addresses and function selectors.
     * @param initializables The addresses of the contracts or facets to execute initializePayloads.
     * @param initializePayloads An array of function calls, including function selectors and arguments
     *                 executed with delegatecall on each initializable contract.
     */
    function updateModules(
        IRootProxy.FacetCut[] calldata facetCuts,
        address[] calldata initializables,
        bytes[] calldata initializePayloads
    )
        external;
}
