// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { ISettlementStrategy } from "./interfaces/ISettlementStrategy.sol";

contract MarketOrderSettlementStrategy is ISettlementStrategy {
    function beforeSettlement(ISettlementModule.SettlementPayload calldata payload) external { }

    function afterSettlement() external { }

    function invoke(uint128 accountId, bytes calldata extraData) external { }
}
