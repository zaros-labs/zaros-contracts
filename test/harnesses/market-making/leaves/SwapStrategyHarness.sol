// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { SwapStrategy } from "@zaros/market-making/leaves/SwapStrategy.sol";

contract SwapStrategyHarness {
    function exposed_setUniswapRouterAddress(address swapRouter) external {
        SwapStrategy.Data storage self = SwapStrategy.load();
        SwapStrategy.setUniswapRouterAddress(self, swapRouter);
    }

    function exposed_setPoolFee(uint24 newFee) external {
        SwapStrategy.Data storage self = SwapStrategy.load();
        SwapStrategy.setPoolFee(self, newFee);
    }

    function exposed_setSlippageTolerance(uint256 newSlippage) external {
        SwapStrategy.Data storage self = SwapStrategy.load();
        SwapStrategy.setSlippageTolerance(self, newSlippage);
    }
}