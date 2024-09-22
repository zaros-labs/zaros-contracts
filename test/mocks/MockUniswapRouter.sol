// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract MockUniswapRouter {
    function exactInputSingle(ISwapRouter.ExactInputSingleParams calldata params)
        external pure
        returns (uint256 amountOut)
    {
        amountOut = params.amountIn; 
    }
}