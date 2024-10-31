// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice The struct for the swap payload.
/// @param tokenIn The token to swap from.
/// @param tokenOut The token to swap to.
/// @param amountIn The token amount to swap.
/// @param recipient The recipient of the swap.
struct SwapPayload {
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    address recipient;
}

/// @notice Swap asset configuration
/// @param decimals The asset decimals
/// @param priceAdapter The asset price adapter
struct SwapAssetConfig {
    uint8 decimals;
    address priceAdapter;
}

/// @notice The interface for the DEX adapter.
interface IDexAdapter {
    /// @notice Executes a swap using the exact input amount, coming from the swap payload passed by the Market Making
    /// Engine.
    /// @return amountOut The amount out returned.
    function executeSwapExactInputSingle(SwapPayload memory swapCallData) external returns (uint256 amountOut);
}
