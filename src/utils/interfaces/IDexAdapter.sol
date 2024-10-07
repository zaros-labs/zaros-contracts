// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

struct SwapCallData {
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 amountOutMin;
    uint256 deadline;
    address recipient;
}

/// @notice The interface for the DEX adapter.
interface IDexAdapter {
    /// @notice Executes a swap with the given calldata.
    /// @return amount The amount returned.
    function executeSwap(SwapCallData memory swapCallData) external view returns (uint256 amount);
}
