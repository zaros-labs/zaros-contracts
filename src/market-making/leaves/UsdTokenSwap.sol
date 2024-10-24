// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";

library UsdTokenSwap {
    /// @notice ERC7201 storage location.
    bytes32 internal constant SWAP_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Swap")) - 1));

    /// @notice Represents a swap request for a user.
    /// @param processed Indicates whether the swap has been processed.
    /// @param amountIn The amount of the input asset provided for the swap.
    /// @param minAmountOut The min amount of the output asset expected after the swap.
    /// @param deadline The deadline by which the swap must be fulfilled.
    /// @param assetOut The address of the asset to be received as the output of the swap.
    /// @param vaultId The id of the vault associated with the swap.
    struct SwapRequest {
        bool processed;
        uint128 amountIn;
        uint128 deadline;
        address assetOut;
        uint128 vaultId;
        uint256 minAmountOut;
    }

    /// @notice Represents the configuration and state data for USD token swaps.
    /// @param baseFee The flat fee for each swap, denominated in USD.
    /// @param swapSettlementFeeBps The swap settlement fee in basis points (bps), applied as a percentage of the swap amount.
    /// @param maxExecutionTime The maximum allowed time, in seconds, to execute a swap after it has been requested.
    /// @param swapRequestIdCounter A counter for tracking the number of swap requests per user address.
    /// @param swapRequests A mapping that tracks all swap requests for each user, by user address and swap request id.
    struct Data {
        uint128 baseFee; // 1 USD
        uint128 swapSettlementFeeBps; // 0.3 %
        uint128 maxExecutionTime;
        mapping(address => uint128) swapRequestIdCounter;
        mapping(address => mapping(uint128 => SwapRequest)) swapRequests;
    }

    /// @notice Loads a {Swap}.
    /// @return swap The loaded swap data storage pointer.
    function load() internal pure returns (Data storage swap) {
        bytes32 slot = keccak256(abi.encode(SWAP_LOCATION));
        assembly {
            swap.slot := slot
        }
    }

    /// @notice Updates the fee and execution time parameters for USD token swaps.
    /// @param baseFee The new flat fee for each swap, denominated in USD.
    /// @param swapSettlementFeeBps The new swap settlement fee in basis points (bps), applied as a percentage of the swap amount.
    /// @param maxExecutionTime The new maximum allowed time, in seconds, to execute a swap after it has been requested.
    function update(uint128 baseFee, uint128 swapSettlementFeeBps, uint128 maxExecutionTime) internal {
        Data storage self = load();

        self.baseFee = baseFee;
        self.swapSettlementFeeBps = swapSettlementFeeBps;
        self.maxExecutionTime = maxExecutionTime;
    }

    /// @notice Increments and returns the next swap request ID for a given user.
    /// @dev This function updates the `swapRequestIdCounter` mapping to generate a unique ID for each user's swap request.
    /// @param user The address of the user for whom the next swap request ID is being generated.
    /// @return id The new incremented swap request ID for the specified user.
    function nextId(Data storage self, address user) internal returns (uint128 id) {
        return ++self.swapRequestIdCounter[user];
    }
}
