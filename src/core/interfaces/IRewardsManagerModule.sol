// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

interface IRewardsManagerModule {
    error Zaros_RewardsManagerModule_RewardUnavailable(address distributor);

    event LogDistributeRewards(
        address indexed collateralType, address distributor, uint256 amount, uint256 start, uint256 duration
    );

    event LogClaimRewards(
        uint128 indexed accountId, address indexed collateralType, address distributor, uint256 amount
    );

    event LogRegisterRewardsDistributor(address indexed collateralType, address indexed distributor);

    event LogRemoveRewardsDistributor(address indexed collateralType, address indexed distributor);

    function registerRewardDistributor(address collateralType, address distributor) external;

    function removeRewardsDistributor(address collateralType, address distributor) external;

    function distributeRewards(address collateralType, uint256 amount, uint64 start, uint32 duration) external;

    function claimRewards(
        uint128 accountId,
        address collateralType,
        address distributor
    )
        external
        returns (uint256 amountClaimed);

    function updateRewards(
        address collateralType,
        uint128 accountId
    )
        external
        returns (UD60x18[] memory claimable, address[] memory distributors);

    function getRewardRate(address collateralType, address distributor) external view returns (uint256 rate);
}
