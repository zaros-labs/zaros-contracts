// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { SwapRouter } from "@zaros/market-making/leaves/SwapRouter.sol";

contract SwapRouterHarness {
    function exposed_swapStrategy_load() external pure returns (SwapRouter.Data memory){
        SwapRouter.Data storage swapRouter = SwapRouter.load();
        return swapRouter;
    }

    function exposed_setSwapStrategy(address swapRouterAddress) external {
        SwapRouter.Data storage swapRouter = SwapRouter.load();
        SwapRouter.setSwapStrategy(swapRouter, swapRouterAddress);
    }

    function exposed_setPoolFee(uint24 newFee) external {
        SwapRouter.Data storage swapRouter = SwapRouter.load();
        SwapRouter.setPoolFee(swapRouter, newFee);
    }

    function exposed_setSlippageTolerance(uint256 newSlippage) external {
        SwapRouter.Data storage swapRouter = SwapRouter.load();
        SwapRouter.setSlippageTolerance(swapRouter, newSlippage);
    }
}