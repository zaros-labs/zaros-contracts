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

    // TODO: Remove orderId after testnet.
    struct SettlementPayload {
        uint128 accountId;
        uint128 orderId;
        int128 sizeDelta;
    }

    function executeMarketOrder(
        uint128 accountId,
        uint128 marketId,
        address settlementFeeReceiver,
        bytes calldata priceData
    )
        external;

    function executeCustomOrders(
        uint128 marketId,
        uint128 settlementId,
        address settlementFeeReceiver,
        SettlementPayload[] calldata payloads,
        bytes calldata priceData,
        address callback
    )
        external;
}
