// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { RootUpgrade } from "../leaves/RootUpgrade.sol";
import { LookupTable } from "../leaves/LookupTable.sol";
import { Branch } from "../leaves/Branch.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

/**
 * @title LookupBranch
 * @notice A loupe is a small magnifying glass used to look at tree-proxy.
 *         See [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535).
 */
contract LookupBranch {
    using RootUpgrade for RootUpgrade.Data;
    using LookupTable for LookupTable.Data;
    using EnumerableSet for *;

    /**
     * @notice Gets all branch addresses and the selectors of supported functions.
     * @return branchInfo An array of Branch structs.
     */
    function branches() external view returns (Branch.Data[] memory) {
        RootUpgrade.Data storage rootUpgrade = RootUpgrade.load();

        return rootUpgrade.getBranches();
    }

    /**
     * @notice Gets all the function selectors supported by a specific branch.
     * @param branch The branch address.
     * @return selectors An array of function selectors.
     */
    function branchFunctionSelectors(address branch) external view returns (bytes4[] memory) {
        RootUpgrade.Data storage rootUpgrade = RootUpgrade.load();

        return rootUpgrade.getBranchSelectors(branch);
    }

    /**
     * @notice Get all the branch addresses used by a root proxy.
     * @return branches The branch addresses.
     */
    function branchAddresses() external view returns (address[] memory) {
        RootUpgrade.Data storage rootUpgrade = RootUpgrade.load();

        return rootUpgrade.getBranchAddresses();
    }

    /**
     * @notice Gets the branch that supports the given selector.
     * @dev If branch is not found return address(0).
     * @param selector The function selector.
     * @return branchAddress The branch address.
     */
    function branchAddress(bytes4 selector) external view returns (address) {
        RootUpgrade.Data storage rootUpgrade = RootUpgrade.load();

        return rootUpgrade.getBranchAddress(selector);
    }

    function branchSelectors(address branch) external view returns (bytes4[] memory) {
        RootUpgrade.Data storage rootUpgrade = RootUpgrade.load();

        return rootUpgrade.getBranchSelectors(branch);
    }
}
