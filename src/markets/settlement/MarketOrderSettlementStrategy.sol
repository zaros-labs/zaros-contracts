// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { DataStreamsSettlementStrategy } from "./DataStreamsSettlementStrategy.sol";

contract MarketOrderSettlementStrategy is DataStreamsSettlementStrategy {
    constructor() {
        _disableInitializers();
    }

    /// @notice {MarketOrderSettlementStrategy} UUPS initializer.
    function initialize(IPerpsEngine perpsEngine, uint128 marketId) external initializer {
        __DataStreamsSettlementStrategy_init(
            perpsEngine, marketId, SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID
        );
    }

    function callback(ISettlementModule.SettlementPayload[] calldata) external override { }

    function executeTrade(
        bytes calldata signedReport,
        bytes calldata extraData
    )
        external
        override
        onlyRegisteredKeeper
    {
        uint128 accountId = abi.decode(extraData, (uint128));
        DataStreamsSettlementStrategyStorage storage dataStreamsCustomSettlementStrategyStorage =
            _getDataStreamsSettlementStrategyStorage();
        (uint128 marketId, IPerpsEngine perpsEngine) = (
            dataStreamsCustomSettlementStrategyStorage.marketId,
            dataStreamsCustomSettlementStrategyStorage.perpsEngine
        );

        // // TODO: Update the fee receiver to an address managed / stored by the keeper.
        perpsEngine.executeMarketOrder(accountId, marketId, msg.sender, signedReport);
    }

    function dispatch(uint128, bytes calldata) external override { }
}
