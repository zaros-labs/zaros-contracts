// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

/// @dev This contract deals with ETH to settle accumulated protocol fees, distributed to LPs and stakeholders.
contract FeeDistributionBranch {
    /// @notice Returns the claimable amount of WETH fees for the given staker at a given vault.
    /// @param vaultId The vault id to claim fees from.
    /// @param staker The staker address.
    /// @return The amount of WETH fees claimable.
    function getEarnedFees(uint256 vaultId, address staker) external view returns (uint256) { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param collateral The margin collateral address.
    /// @param amount The token amount of collateral to receive as fee.
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
    /// @param vaultId The vault id to claim fees from.
    function claimFees(uint256 vaultId) external { }
}
