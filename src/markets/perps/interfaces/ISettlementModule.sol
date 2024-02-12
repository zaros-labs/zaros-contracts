// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { MarketOrder } from "../storage/MarketOrder.sol";
import { Position } from "../storage/Position.sol";

interface ISettlementModule {
    event LogSettleOrder(
        address indexed sender,
        uint128 indexed accountId,
        uint128 indexed marketId,
        int256 sizeDelta,
        uint256 fillPrice,
        int256 orderFeeUsd,
        uint256 settlementFeeUsd,
        int256 pnl,
        Position.Data newPosition
    );

    struct SettlementPayload {
        uint128 accountId;
        int128 sizeDelta;
    }

    function settleMarketOrder(uint128 accountId, uint128 marketId, bytes calldata verifiedReportData) external;

    function settleCustomOrders(
        uint128 marketId,
        uint128 settlementId,
        SettlementPayload[] calldata payloads,
        bytes calldata verifiedReportData
    )
        external;
}
