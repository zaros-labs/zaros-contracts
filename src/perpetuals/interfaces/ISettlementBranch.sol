// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { FeeRecipients } from "../leaves/FeeRecipients.sol";

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
        int256 fundingFeePerUnit
    );

    struct SettlementPayload {
        uint128 accountId;
        int128 sizeDelta;
    }

    function fillMarketOrder(
        uint128 accountId,
        uint128 marketId,
        FeeRecipients.Data calldata feeRecipients,
        bytes calldata priceData
    )
        external;

    function fillCustomOrders(
        uint128 marketId,
        uint128 settlementConfigurationId,
        address settlementFeeRecipient,
        SettlementPayload[] calldata payloads,
        bytes calldata priceData,
        address callback
    )
        external;
}
