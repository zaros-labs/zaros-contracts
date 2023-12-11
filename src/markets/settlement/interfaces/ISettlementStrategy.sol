// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";

interface ISettlementStrategy {
    function beforeSettlement(ISettlementModule.SettlementPayload calldata payload) external;

    function afterSettlement() external;

    function invoke(uint128 accountId, bytes calldata extraData) external;

    function settle(bytes calldata reportData, ISettlementModule.SettlementPayload[] calldata payloads) external;
}
