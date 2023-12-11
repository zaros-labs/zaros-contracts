// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { ISettlementStrategy } from "./interfaces/ISettlementStrategy.sol";
import { DataStreamsSettlementStrategy } from "./DataStreamsSettlementStrategy.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

contract OcoOrderSettlementStrategy is DataStreamsSettlementStrategy, ISettlementStrategy {
    function beforeSettlement(ISettlementModule.SettlementPayload calldata payload) external override { }

    function afterSettlement() external override onlyPerpsEngine { }

    function invoke(uint128 accountId, bytes calldata extraData) external override onlyPerpsEngine {
        (Actions action) = abi.decode(extraData[0:8], (Actions));

        if (action == Actions.UPDATE_OCO_ORDER) {
            (OcoOrder.TakeProfit memory takeProfit, OcoOrder.StopLoss memory stopLoss) =
                abi.decode(extraData[8:], (OcoOrder.TakeProfit, OcoOrder.StopLoss));

            _updateOcoOrder(accountId, takeProfit, stopLoss);
        } else {
            revert Errors.InvalidSettlementStrategyAction();
        }
    }
}
