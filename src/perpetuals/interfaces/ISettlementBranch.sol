// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { MarketOrder } from "../leaves/MarketOrder.sol";
import { Position } from "../leaves/Position.sol";

interface ISettlementBranch {
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

    function fillMarketOrder(
        uint128 accountId,
        uint128 marketId,
        address settlementFeeReceiver,
        bytes calldata priceData
    )
        external;

    function fillCustomOrders(
        uint128 marketId,
        uint128 settlementConfigurationId,
        address settlementFeeReceiver,
        SettlementPayload[] calldata payloads,
        bytes calldata priceData,
        address callback
    )
        external;
}
