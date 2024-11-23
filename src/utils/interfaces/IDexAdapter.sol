// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice The struct for the swap exact input single payload.
/// @param tokenIn The token to swap from.
/// @param tokenOut The token to swap to.
/// @param amountIn The token amount to swap.
/// @param recipient The recipient of the swap.
struct SwapExactInputSinglePayload {
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    address recipient;
}

/// @notice The struct for the swap exact input payload.
/// @param path The path is a sequence of (tokenAddress - fee - tokenAddress),
/// which are the variables needed to compute each pool contract address in our sequence of swaps.
/// The multihop swap router code will automatically find the correct pool with these variables,
/// and execute the swap needed within each pool in our sequence.
/// @param tokenIn The token to swap from.
/// @param tokenOut The token to swap to.
/// @param recipient The recipient of the swap.
/// @param amountIn The token amount to swap.
struct SwapExactInputPayload {
    bytes path;
    address tokenIn;
    address tokenOut;
    address recipient;
    uint256 amountIn;
}

/// @notice The interface for the DEX adapter.
interface IDexAdapter {
    /// @notice Executes a swap using the exact input single amount, coming from the swap payload passed by the Market
    /// Making Engine.
    /// @return amountOut The amount out returned.
    function executeSwapExactInputSingle(
        SwapExactInputSinglePayload memory swapCallData
    )
        external
        returns (uint256 amountOut);

    /// @notice Executes a swap using the exact input amount, coming from the swap payload passed by the Market Making
    /// Engine.
    /// @return amountOut The amount out returned.
    function executeSwapExactInput(SwapExactInputPayload calldata swapPayload) external returns (uint256 amountOut);
}
