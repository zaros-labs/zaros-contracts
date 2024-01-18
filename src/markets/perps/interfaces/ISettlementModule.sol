// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { MarketOrder } from "../storage/MarketOrder.sol";
import { Position } from "../storage/Position.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

interface ISettlementModule {
    event LogSettleOrder(
        address indexed sender,
        uint128 indexed accountId,
        uint128 indexed marketId,
        int256 pnl,
        Position.Data newPosition
    );

    struct SettlementPayload {
        uint128 accountId;
        int128 sizeDelta;
    }

    /// @notice Validates if the given account will still meet margin requirements when updating its position at
    /// `marketId`.
    /// @dev Reverts if the newPosition results on an invalid state (requiredMargin >= marginBalance)
    /// @param accountId The account id to be validated.
    /// @param marketId The market id to be validated.
    /// @param newPosition The new position state after the settlement.
    function validateMarginRequirements(
        uint128 accountId,
        uint128 marketId,
        Position.Data memory newPosition
    )
        external
        view;

    function settleMarketOrder(uint128 accountId, uint128 marketId, bytes calldata verifiedReportData) external;

    function settleCustomTriggers(
        uint128 marketId,
        uint128 settlementId,
        SettlementPayload[] calldata payloads,
        bytes calldata verifiedReportData
    )
        external;
}
