// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { IZaros } from "@zaros/core/interfaces/IZaros.sol";
import { IRewardDistributor } from "@zaros/reward-distributor/interfaces/IRewardDistributor.sol";
import { IZarosUSD } from "@zaros/usd/interfaces/IZarosUSD.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract DistributeReward is BaseScript {
    function run() public broadcaster {
        IZarosUSD usdToken = IZarosUSD(vm.envAddress("ZRSUSD"));
        IRewardDistributor rewardDistributor = IRewardDistributor(vm.envAddress("REWARD_DISTRIBUTOR"));
        address sFrxEth = vm.envAddress("SFRXETH");
        address usdc = vm.envAddress("USDC");

        uint256 testDistributionAmount = 500e18;
        usdToken.mint(address(rewardDistributor), testDistributionAmount);

        rewardDistributor.distributeRewards(sFrxEth, testDistributionAmount / 2, 0, 0);
        rewardDistributor.distributeRewards(usdc, testDistributionAmount / 2, 0, 0);
    }
}
