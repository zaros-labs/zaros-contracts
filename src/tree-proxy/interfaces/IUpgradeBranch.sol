// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IRootProxy } from "./IRootProxy.sol";

/**
 * @title IRootUpgrade
 * @notice Interface of the RootUpgrade branch. See [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535).
 */
interface IUpgradeBranch {
    /**
     * @notice Add/replace/remove any number of functions and optionally execute
     *         a function with delegatecall.
     * @param branchUpgrades Contains the branch addresses and function selectors.
     * @param initializables The addresses of the contracts or branches to execute initializePayloads.
     * @param initializePayloads An array of function calls, including function selectors and arguments
     *                 executed with delegatecall on each initializable contract.
     */
    function upgrade(
        IRootProxy.BranchUpgrade[] calldata branchUpgrades,
        address[] calldata initializables,
        bytes[] calldata initializePayloads
    )
        external;
}
