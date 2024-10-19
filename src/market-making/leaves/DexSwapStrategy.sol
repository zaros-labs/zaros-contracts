// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IDexAdapter, SwapPayload } from "@zaros/utils/interfaces/IDexAdapter.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice DexSwapStrategy library for executing swaps on a DEX.
library DexSwapStrategy {
    /// @notice ERC7201 storage location.
    bytes32 internal constant DEX_SWAP_STRATEGY_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.DexSwapStrategy")) - 1));

    uint256 internal constant BPS_DENOMINATOR = 10_000;

    /// @notice DexSwapStrategy data storage struct.
    /// @param id The unique identifier of the DexSwapStrategy.
    /// @param dexAdapter The address of the DexAdapter contract.
    struct Data {
        uint128 id;
        address dexAdapter;
    }

    /// @notice Loads a {DexSwapStrategy}.
    /// @return dexSwapStrategy The loaded dex swap strategy storage pointer.
    function load(uint128 dexSwapStrategyId) internal pure returns (Data storage dexSwapStrategy) {
        bytes32 slot = keccak256(abi.encode(DEX_SWAP_STRATEGY_LOCATION, dexSwapStrategyId));
        assembly {
            dexSwapStrategy.slot := slot
        }
    }

    /// @notice Executes a swap with the given calldata on the configured router.
    /// @param self The SwapRouter data storage.
    /// @param swapCallData The calldata to perform the swap.
    /// @return amountOut The result of the swap execution.
    function executeSwapExactInputSingle(
        Data storage self,
        SwapPayload memory swapCallData
    )
        internal
        returns (uint256 amountOut)
    {
        IDexAdapter dexAdapter = IDexAdapter(self.dexAdapter);
        return dexAdapter.executeSwapExactInputSingle(swapCallData);
    }
}
