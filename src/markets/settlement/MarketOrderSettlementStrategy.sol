// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { DataStreamsCustomSettlementStrategy } from "./DataStreamsCustomSettlementStrategy.sol";

contract MarketOrderSettlementStrategy is DataStreamsCustomSettlementStrategy {
    function beforeSettlement(ISettlementModule.SettlementPayload calldata payload) external override { }

    function afterSettlement() external override { }

    function settle(bytes calldata signedReport, bytes calldata extraData) external override onlyRegisteredKeeper {
        uint128 accountId = abi.decode(extraData, (uint128));
        DataStreamsCustomSettlementStrategyStorage storage dataStreamsCustomSettlementStrategyStorage =
            _getDataStreamsCustomSettlementStrategyStorage();
        (uint128 marketId, PerpsEngine perpsEngine) = (
            dataStreamsCustomSettlementStrategyStorage.marketId, dataStreamsCustomSettlementStrategyStorage.perpsEngine
        );

        perpsEngine.settleMarketOrder(accountId, marketId, signedReport);
    }

    function invoke(uint128, bytes calldata) external override { }
}
