// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IDexAdapter, SwapPayload } from "@zaros/utils/interfaces/IDexAdapter.sol";

library DexSwapStrategy {
    /// @notice ERC7201 storage location.
    bytes32 internal constant SWAP_ROUTER_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.DexSwapStrategy")) - 1));

    uint256 internal constant BPS_DENOMINATOR = 10_000;

    // TODO: add natspec
    struct Data {
        uint128 id;
        address dexAdapter;
    }

    /// @notice Loads a {DexSwapStrategy}.
    /// @return dexSwapStrategy The loaded dex swap strategy storage pointer.
    function load(uint128 dexSwapStrategyId) internal pure returns (Data storage dexSwapStrategy) {
        bytes32 slot = keccak256(abi.encode(SWAP_ROUTER_LOCATION, dexSwapStrategyId));
        assembly {
            dexSwapStrategy.slot := slot
        }
    }

    /// @notice Executes a swap with the given calldata on the configured router.
    /// @param self The SwapRouter data storage.
    /// @param swapCallData The calldata to perform the swap.
    /// @return amount The result of the swap execution.
    function executeSwapExactInputSingle(
        Data storage self,
        SwapPayload memory swapCallData
    )
        internal
        returns (uint256 amount)
    {
        IDexAdapter dexAdapter = IDexAdapter(self.dexAdapter);
        return dexAdapter.executeSwapExactInputSingle(swapCallData);
    }
}
