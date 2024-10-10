// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;
pragma abicoder v2;

// Zaros dependencies
import { ISwapRouter } from "@zaros/utils/interfaces/ISwapRouter.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

/// @title mock Uniswap V3 Swap Strategy Router
/// @notice Router for stateless execution of swaps against Uniswap V3
contract MockUniswapV3SwapStrategyRouter is ISwapRouter {
    /// @dev Used as the placeholder value for amountInCached, because the computed amount in for an exact output swap
    /// can never actually be this value
    uint256 private constant DEFAULT_AMOUNT_IN_CACHED = type(uint256).max;

    /// @dev Transient storage variable used for returning the computed amount in for an exact output swap.
    uint256 private amountInCached = DEFAULT_AMOUNT_IN_CACHED;

    struct SwapCallbackData {
        bytes path;
        address payer;
    }

    /// @dev Performs a single exact input swap
    function exactInputInternal(
        uint256 amountIn,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    )
        private
        pure
        returns (uint256 amountOut)
    {
        // only for mock purposes
        recipient;
        sqrtPriceLimitX96;
        data;
        amountOut = amountIn;
    }

    /// @inheritdoc ISwapRouter
    function exactInputSingle(
        ExactInputSingleParams calldata params
    )
        external
        payable
        override
        returns (
            // checkDeadline(params.deadline)
            uint256 amountOut
        )
    {
        IERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        IERC20(params.tokenOut).transfer(params.recipient, params.amountIn);

        amountOut = exactInputInternal(
            params.amountIn,
            params.recipient,
            params.sqrtPriceLimitX96,
            SwapCallbackData({ path: abi.encodePacked(params.tokenIn, params.fee, params.tokenOut), payer: msg.sender })
        );
        require(amountOut >= params.amountOutMinimum, "Too little received");
    }

    /// @inheritdoc ISwapRouter
    function exactInput(
        ExactInputParams memory params
    )
        external
        payable
        override
        returns (
            // checkDeadline(params.deadline)
            uint256 amountOut
        )
    { }

    /// @dev Performs a single exact output swap
    function exactOutputInternal(
        uint256 amountOut,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    )
        private
        returns (uint256 amountIn)
    { }

    /// @inheritdoc ISwapRouter
    function exactOutputSingle(
        ExactOutputSingleParams calldata params
    )
        external
        payable
        override
        returns (
            // checkDeadline(params.deadline)
            uint256 amountIn
        )
    { }

    /// @inheritdoc ISwapRouter
    function exactOutput(
        ExactOutputParams calldata params
    )
        external
        payable
        override
        returns (
            // checkDeadline(params.deadline)
            uint256 amountIn
        )
    { }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override { }
}
