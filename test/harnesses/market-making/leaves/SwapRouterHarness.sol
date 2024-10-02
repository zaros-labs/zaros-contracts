// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { SwapRouter } from "@zaros/market-making/leaves/SwapRouter.sol";

contract SwapRouterHarness {
    function exposed_swapStrategy_load(uint128 swapRouterId) external pure returns (SwapRouter.Data memory){
        SwapRouter.Data storage swapRouter = SwapRouter.load(swapRouterId);
        return swapRouter;
    }

    function exposed_setSwapStrategy(uint128 swapRouterId, address swapRouterAddress) external {
        SwapRouter.Data storage swapRouter = SwapRouter.load(swapRouterId);
        SwapRouter.setSwapStrategy(swapRouter, swapRouterAddress);
    }

    function exposed_setPoolFee(uint128 swapRouterId, uint24 newFee) external {
        SwapRouter.Data storage swapRouter = SwapRouter.load(swapRouterId);
        SwapRouter.setPoolFee(swapRouter, newFee);
    }

    function exposed_setSlippageTolerance(uint128 swapRouterId, uint256 newSlippage) external {
        SwapRouter.Data storage swapRouter = SwapRouter.load(swapRouterId);
        SwapRouter.setSlippageTolerance(swapRouter, newSlippage);
    }
}