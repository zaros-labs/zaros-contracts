// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

/**
 * @title IRootProxy
 * @notice Interface of the RootProxy Proxy contract.
 */
interface IRootProxy {
    /// @notice Branch upgrade action types.
    enum BranchUpgradeAction {
        Add,
        Replace,
        Remove
    }

    /// @notice Describes a branch to be added, replaced or removed.
    /// @param branch Address of the branch, that contains the functions.
    /// @param action The action to be performed.
    /// @param selectors The function selectors of the branch to be cut.
    struct BranchUpgrade {
        address branch;
        BranchUpgradeAction action;
        bytes4[] selectors;
    }
}
