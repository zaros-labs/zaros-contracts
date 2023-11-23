// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { ILiquidityEngine } from "@zaros/liquidity/interfaces/ILiquidityEngine.sol";
import { IBalancerVault } from "@zaros/external/balancer/interfaces/IBalancerVault.sol";
import { BalancerUSDCStrategy } from "@zaros/strategies/BalancerUSDCStrategy.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract WithdrawFromStrategy is BaseScript {
    function run() public broadcaster {
        IERC20 usdc = IERC20(vm.envAddress("USDC"));
        ILiquidityEngine liquidityEngine = ILiquidityEngine(vm.envAddress("ZAROS"));
        BalancerUSDCStrategy balancerUsdcStrategy = BalancerUSDCStrategy(vm.envAddress("BALANCER_USDC_STRATEGY"));
        IBalancerVault balancerVault = IBalancerVault(vm.envAddress("BALANCER_VAULT"));
        bytes32 poolId = vm.envBytes32("USDZ_USDC_POOL_ID");
        (address bpt,) = balancerVault.getPool(poolId);

        uint256 strategyBptBalance = IERC20(bpt).balanceOf(address(balancerUsdcStrategy));
        uint256 liquidityEngineStrategySharesAmount = balancerUsdcStrategy.balanceOf(address(liquidityEngine));
        // TODO: add min amounts out
        uint256[] memory minAmountsOut = new uint256[](2);
        balancerUsdcStrategy.removeLiquidityFromPool(strategyBptBalance, minAmountsOut);
        liquidityEngine.withdrawFromStrategy(address(usdc), liquidityEngineStrategySharesAmount, 0);
    }
}
