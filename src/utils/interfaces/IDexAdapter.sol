// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice The struct for the swap payload.
/// @param tokenIn The token to swap from.
/// @param tokenOut The token to swap to.
/// @param amountIn The token amount to swap.
/// @param deadline The deadline for the swap.
/// @param recipient The recipient of the swap.
struct SwapPayload {
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 deadline;
    address recipient;
}

/// @notice The interface for the DEX adapter.
interface IDexAdapter {
    /// @notice Executes a swap exact input with the given calldata.
    /// @return amountOut The amount out returned.
    function executeSwapExactInputSingle(SwapPayload memory swapCallData) external returns (uint256 amountOut);
}
