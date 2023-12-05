// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Order } from "../storage/Order.sol";
import { Position } from "../storage/Position.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

interface ISettlementModule {
    event LogSettleOrder(
        address indexed sender, uint256 indexed accountId, uint128 indexed marketId, Position.Data newPosition
    );

    struct SettlementPayload {
        uint128 accountId;
        int128 sizeDelta;
    }

    struct SettlementRuntime {
        uint128 marketId;
        uint128 accountId;
        UD60x18 fee;
        UD60x18 fillPrice;
        SD59x18 unrealizedPnlToStore;
        SD59x18 pnl;
        Position.Data newPosition;
    }

    function settleMarketOrder(uint128 accountId, uint128 marketId, bytes calldata verifiedReportData) external;

    function settleCustomTriggers(
        uint128 marketId,
        uint128 strategyId,
        SettlementPayload[] calldata payloads,
        bytes calldata verifiedReportData
    )
        external;
}
