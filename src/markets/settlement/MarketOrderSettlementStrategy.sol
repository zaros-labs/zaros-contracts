// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { DataStreamsSettlementStrategy } from "./DataStreamsSettlementStrategy.sol";

contract MarketOrderSettlementStrategy is DataStreamsSettlementStrategy {
    /// @notice {MarketOrderSettlementStrategy} UUPS initializer.
    function initialize(PerpsEngine perpsEngine, address[] calldata keepers, uint128 marketId) external initializer {
        __DataStreamsSettlementStrategy_init(
            perpsEngine, keepers, marketId, SettlementConfiguration.MARKET_ORDER_SETTLEMENT_ID
        );
    }

    // TODO: Implement
    // function getConfig() external view;

    function beforeSettlement(ISettlementModule.SettlementPayload calldata payload) external override { }

    function afterSettlement() external override { }

    function settle(bytes calldata signedReport, bytes calldata extraData) external override onlyRegisteredKeeper {
        uint128 accountId = abi.decode(extraData, (uint128));
        DataStreamsSettlementStrategyStorage storage dataStreamsCustomSettlementStrategyStorage =
            _getDataStreamsSettlementStrategyStorage();
        (uint128 marketId, PerpsEngine perpsEngine) = (
            dataStreamsCustomSettlementStrategyStorage.marketId,
            dataStreamsCustomSettlementStrategyStorage.perpsEngine
        );

        perpsEngine.settleMarketOrder(accountId, marketId, signedReport);
    }

    function dispatch(uint128, bytes calldata) external override { }
}
