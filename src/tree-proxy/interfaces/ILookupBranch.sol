// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { Branch } from "../leaves/Branch.sol";

/**
 * @title ILookupBranch
 * @notice A loupe is a small magnifying glass used to look at tree-proxy.
 *         See [EIP-2535](https://eips.ethereum.org/EIPS/eip-2535).
 */
interface ILookupBranch {
    /**
     * @notice Gets all branch addresses and the selectors of supported functions.
     * @return branchInfo An array of Branch structs.
     */
    function branches() external view returns (Branch.Data[] memory);

    /**
     * @notice Gets all the function selectors supported by a specific branch.
     * @param branch The branch address.
     * @return selectors An array of function selectors.
     */
    function branchFunctionSelectors(address branch) external view returns (bytes4[] memory);

    /**
     * @notice Get all the branch addresses used by a root proxy.
     * @return branches The branch addresses.
     */
    function branchAddresses() external view returns (address[] memory);

    /**
     * @notice Gets the branch that supports the given selector.
     * @dev If branch is not found return address(0).
     * @param selector The function selector.
     * @return branchAddress The branch address.
     */
    function branchAddress(bytes4 selector) external view returns (address);

    function branchSelectors(address branch) external view returns (bytes4[] memory);
}
