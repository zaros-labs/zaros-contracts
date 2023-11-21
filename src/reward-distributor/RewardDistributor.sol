// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { IRewardsManagerModule } from "@zaros/liquidity/interfaces/IRewardsManagerModule.sol";
import { IRewardDistributor } from "./interfaces/IRewardDistributor.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract RewardDistributor is IRewardDistributor {
    address private _rewardManager;
    address private _rewardToken;
    string private _name;

    constructor(address rewardManager_, address rewardToken_, string memory name_) {
        _rewardManager = rewardManager_;
        _rewardToken = rewardToken_;
        _name = name_;
    }

    function rewardManager() external view override returns (address) {
        return _rewardManager;
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function rewardToken() external view override returns (address) {
        return _rewardToken;
    }

    function payout(uint128, address, address sender, uint256 amount) external override returns (bool) {
        if (msg.sender != _rewardManager) {
            revert Errors.Unauthorized(msg.sender);
        }
        IERC20(_rewardToken).transfer(sender, amount);
        return true;
    }

    function distributeRewards(address collateralType, uint256 amount, uint64 start, uint32 duration) public override {
        IRewardsManagerModule(_rewardManager).distributeRewards(collateralType, amount, start, duration);
    }

    function onPositionUpdated(uint128, address, uint256) external pure override {
        return;
    }
}
