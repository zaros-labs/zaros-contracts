// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Solady dependencies
import { MinHeapLib } from "@solady/Milady.sol";

library SystemDebt {
    bytes32 internal constant GLOBAL_DEBT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.SystemDebt")) - 1));

    // TODO: work on encoding nodes into the priority queue
    struct PriorityQueueNode {
        uint128 vaultId;
        int128 debt;
    }

    // TODO: pack storage slots
    struct Data {
        int256 totalUnsettledDebtUsd;
        int256 totalSettledDebtUsd;
        MinHeapLib.Heap vaultsDebtSettlementPriorityQueue;
    }

    /// @notice Loads the {SystemDebt} namespace.
    function load() internal pure returns (Data storage systemDebt) {
        bytes32 slot = keccak256(abi.encode(GLOBAL_DEBT_LOCATION));
        assembly {
            systemDebt.slot := slot
        }
    }
}
