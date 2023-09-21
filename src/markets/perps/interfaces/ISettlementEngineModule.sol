// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Order } from "../storage/Order.sol";
import { Position } from "../storage/Position.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

interface ISettlementEngineModule {
    event LogSettleOrder(
        address indexed sender,
        uint256 indexed accountId,
        uint128 indexed marketId,
        Order.Data order,
        Position.Data newPosition
    );

    struct SettlementRuntime {
        uint128 marketId;
        uint256 accountId;
        UD60x18 fillPrice;
        SD59x18 unrealizedPnlToStore;
        SD59x18 pnl;
        Position.Data newPosition;
    }
}
