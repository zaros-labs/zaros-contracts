// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract UniswapV3Adapter is UUPSUpgradeable {
    // TODO: define EIP7201 storage
    function executeSwap(SwapCallData calldata swapData) external {
        // Execute swap

        ISwapRouter swapRouter = ISwapRouter(self.router);

        swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: swapData.tokenIn,
                tokenOut: swapData.tokenOut,
                fee: self.poolFee,
                recipient: swapData.recipient,
                deadline: swapData.deadline,
                amountIn: swapData.amountIn,
                amountOutMinimum: swapData.amountOutMin,
                sqrtPriceLimitX96: 0
            })
        );
    }
}
