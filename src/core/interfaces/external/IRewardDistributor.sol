// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/// @title Interface a reward distributor.
interface IRewardDistributor {
    function name() external returns (string memory);

    function payout(
        uint128 accountId,
        address collateralType,
        address sender,
        uint256 amount
    )
        external
        returns (bool);

    function onPositionUpdated(uint128 accountId, address collateralType, uint256 newShares) external;

    function token() external returns (address);
}
