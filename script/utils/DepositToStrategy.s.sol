// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { ILiquidityEngine } from "@zaros/liquidity/interfaces/ILiquidityEngine.sol";
import { BalancerUSDCStrategy } from "@zaros/strategies/BalancerUSDCStrategy.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract DepositToStrategy is BaseScript {
    function run() public broadcaster {
        IERC20 usdc = IERC20(vm.envAddress("USDC"));
        ILiquidityEngine liquidityEngine = ILiquidityEngine(vm.envAddress("ZAROS"));
        BalancerUSDCStrategy balancerUsdcStrategy = BalancerUSDCStrategy(vm.envAddress("BALANCER_USDC_STRATEGY"));

        uint256 usdTokencCollateralBalance = usdc.balanceOf(address(liquidityEngine));
        // TODO: add min amounts out
        liquidityEngine.depositToStrategy(address(usdc), usdTokencCollateralBalance, 0);
        balancerUsdcStrategy.addLiquidityToPool(0);
    }
}
