// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

contract StabilityBranch {
    /// @dev Swap is fulfilled by a registered keeper.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function initiateSwap() external { }

    /// @dev Called by data streams powered keeper.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function fulfillSwap() external { }
}
