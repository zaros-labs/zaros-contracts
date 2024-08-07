// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

/// @dev This contract deals with ETH to settle accumulated protocol fees, distributed to LPs and stakeholders.
contract FeeDistributionBranch {
    function getEarnedFees(address staker) external view returns (uint256) { }

    function receiveOrderFee(address collateral, uint256 amount) external { }

    function convertAccumulatedFeesToWeth() external { }

    function sendWethToFeeDistributor() external { }

    function sendWethToFeeRecipients() external { }

    function claimEarnedFees() external { }
}
