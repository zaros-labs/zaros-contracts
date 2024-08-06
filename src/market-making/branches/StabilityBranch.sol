// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

contract StabilityBranch {
    /// @dev Swap is fulfilled by a registered keeper.
    function initiateSwap() external { }

    /// @dev Called by data streams powered keeper.
    function fulfillSwap() external { }
}
