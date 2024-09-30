// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Solady dependencies
import { MinHeapLib } from "@solady/Milady.sol";

/// @dev Zaros Protocol Debt Distribution System:
/// market unrealized debt -> market realized debt (when triggered by engine) -> vault unsettled debt (flushed from
/// market unrealized debt) -> vault settled debt (flushed from vault unsettled debt, triggered by keeper)
library SystemDebt {
    bytes32 internal constant SYSTEM_DEBT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.SystemDebt")) - 1));

    // TODO: work on encoding nodes into the priority queue
    struct PriorityQueueNode {
        uint128 vaultId;
        int128 debt;
    }

    // TODO: pack storage slots
    struct Data {
        int128 totalUnsettledDebtUsd;
        int128 totalSettledDebtUsd;
        MinHeapLib.Heap vaultsDebtSettlementPriorityQueue;
    }

    /// @notice Loads the {SystemDebt} namespace.
    /// @return systemDebt The loaded system debt storage pointer.
    function load() internal pure returns (Data storage systemDebt) {
        bytes32 slot = keccak256(abi.encode(SYSTEM_DEBT_LOCATION));
        assembly {
            systemDebt.slot := slot
        }
    }
}
