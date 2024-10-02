// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";

library SwapRouter {
    /// @notice ERC7201 storage location.
    bytes32 internal constant SWAP_ROUTER_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.SwapRouter")) - 1));

    uint256 internal constant BPS_DENOMINATOR = 10_000;
    uint256 internal constant MIN_POOL_FEE = 1000;
    uint256 internal constant MIN_SLIPPAGE_TOLERANCE = 100;

    /// @param swapRouter The UniswapV3 ISwapRouter contract address used for executing swaps.
    /// @param poolFee The fee tier of the Uniswap pool to be used for swaps, measured in basis points.
    /// @param slippageTolerance The maximum slippage allowed for a swap, expressed in basis points (1% = 100 basis points).
    struct Data {
        uint128 swapRouterId;
        bytes4 selector;
        uint24 poolFee;
        address swapStrategy;
        uint256 slippageTolerance;
        uint256 deadline;
    }

    /// @notice Loads a {SwapRouter}.
    /// @return swapRouter The loaded swap router storage pointer.
    function load(uint128 swapRouterId) internal pure returns (Data storage swapRouter) {
        bytes32 slot = keccak256(abi.encode(SWAP_ROUTER_LOCATION, swapRouterId));
        assembly {
            swapRouter.slot := slot
        }
    }

    /// @notice Sets the router address and router call data required for executing swaps.
    /// @param self The SwapRouter data storage.
    /// @param swapStrategy The address of the swap strategy contract.
    function setSwapStrategy(Data storage self, address swapStrategy) internal {
        if (self.swapStrategy == address(0)) revert Errors.ZeroInput("swapRouter address");
        self.swapStrategy = swapStrategy;
    }

    /// @notice Executes a swap with the given calldata on the configured router.
    /// @param self The SwapRouter data storage.
    /// @param routerCallData The calldata to perform the swap.
    /// @return The result of the swap execution.
    function executeSwap(
        Data storage self,
        bytes memory routerCallData
    ) 
        internal 
        returns (uint256)
    {
        (bool success, bytes memory result) = self.swapStrategy.call(abi.encode(self.selector, routerCallData));
        if (!success) {
            revert Errors.SwapExecutionFailed();
        }
        return abi.decode(result, (uint256));
    }

    /// @notice Sets pool fee
    /// @dev the minimum is 1000 (e.g. 0.1%)
    function setPoolFee(Data storage self, uint24 newFee) internal {
        if(newFee < MIN_POOL_FEE) revert Errors.InvalidPoolFee();
        self.poolFee = newFee;
    }

    /// @notice Sets slippage tolerance
    /// @dev the minimum is 100 (e.g. 1%)
    function setSlippageTolerance(Data storage self, uint256 newSlippageTolerance) internal {
        if(newSlippageTolerance < MIN_SLIPPAGE_TOLERANCE) revert Errors.InvalidSlippage();
        self.slippageTolerance = newSlippageTolerance;
    }

    /// @notice Sets the deadline
    /// @param newDeadline The new deadline
    function setDeadline(Data storage self, uint256 newDeadline) internal {
        if(newDeadline < block.timestamp) revert Errors.InvalidDeadline();
        self.deadline = newDeadline;
    }

    /// @notice Sets function selector
    /// @param newSelector The new selector
    function setSelector(Data storage self, bytes4 newSelector) internal {
        self.selector = newSelector;
    }
}
