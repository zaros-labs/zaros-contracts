// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

/// @dev This contract deals with ETH to settle accumulated protocol fees, distributed to LPs and stakeholders.
contract FeeDistributionBranch {
    function getEarnedFees(uint256 vaultId, address staker) external view returns (uint256) { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function receiveOrderFee(address collateral, uint256 amount) external { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function convertAccumulatedFeesToWeth() external { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function sendWethToFeeDistributor() external { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function sendWethToFeeRecipients() external { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function claimFees(uint256 vaultId) external { }
}
