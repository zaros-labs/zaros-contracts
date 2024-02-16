// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";

interface ISettlementStrategy {
    function callback(ISettlementModule.SettlementPayload[] calldata payloads) external;

    function dispatch(uint128 accountId, bytes calldata priceData) external;
}
