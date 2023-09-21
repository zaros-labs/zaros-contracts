// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Position } from "../storage/Position.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

interface ISettlementEngineModule {
    struct SettlementRuntime {
        uint256 marketId;
        uint128 accountId;
        uint8 orderId;
        SD59x18 sizeDelta;
        SD59x18 initialMarginDelta;
        UD60x18 price;
        SD59x18 unrealizedPnlToStore;
        SD59x18 pnl;
        Position.Data newPosition;
    }
}
