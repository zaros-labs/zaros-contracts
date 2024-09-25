// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { SwapStrategy } from "@zaros/market-making/leaves/SwapStrategy.sol";

contract SwapStrategyHarness {
    function exposed_UniswapRouterAddress_load() external pure returns (SwapStrategy.Data memory){
        SwapStrategy.Data storage swapStrategyData = SwapStrategy.load();
        return swapStrategyData;
    }

    function exposed_setUniswapRouterAddress(address swapRouter) external {
        SwapStrategy.Data storage swapStrategyData = SwapStrategy.load();
        SwapStrategy.setUniswapRouterAddress(swapStrategyData, swapRouter);
    }

    function exposed_setPoolFee(uint24 newFee) external {
        SwapStrategy.Data storage swapStrategyData = SwapStrategy.load();
        SwapStrategy.setPoolFee(swapStrategyData, newFee);
    }

    function exposed_setSlippageTolerance(uint256 newSlippage) external {
        SwapStrategy.Data storage swapStrategyData = SwapStrategy.load();
        SwapStrategy.setSlippageTolerance(swapStrategyData, newSlippage);
    }
}