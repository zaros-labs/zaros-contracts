// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Fee } from "@zaros/market-making/leaves/Fee.sol";

contract FeeHarness {
    function exposed_setUniswapRouterAddress(address swapRouter) external {
        Fee.Uniswap storage self = Fee.load_Uniswap();
        Fee.setUniswapRouterAddress(self, swapRouter);
    }

    function exposed_setPoolFee(uint24 newFee) external {
        Fee.Uniswap storage self = Fee.load_Uniswap();
        Fee.setPoolFee(self, newFee);
    }

    function exposed_setSlippage(uint256 newSlippage) external {
        Fee.Uniswap storage self = Fee.load_Uniswap();
        Fee.setSlippage(self, newSlippage);
    }
}