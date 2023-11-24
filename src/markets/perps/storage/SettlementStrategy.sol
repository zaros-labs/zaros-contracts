// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

library SettlementStrategy {
    enum StrategyType {
        DATA_STREAMS_MARKET_ORDER,
        DATA_STREAMS_LIMIT_ORDER
    }

    struct Data {
        StrategyType strategyType;
        bytes strategyData;
    }

    struct DataStreamsMarketOrder {
        string streamId;
        string feedLabel;
        string queryLabel;
        address upkeep;
        uint96 settlementDelay;
    }
}
