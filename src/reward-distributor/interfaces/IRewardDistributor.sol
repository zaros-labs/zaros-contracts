// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

/// @title Interface a reward distributor.
interface IRewardDistributor {
    function rewardManager() external returns (address);

    function name() external returns (string memory);

    function rewardToken() external returns (address);

    function payout(
        uint128 accountId,
        address collateralType,
        address sender,
        uint256 amount
    )
        external
        returns (bool);

    function onPositionUpdated(uint128 accountId, address collateralType, uint256 newShares) external;
}
