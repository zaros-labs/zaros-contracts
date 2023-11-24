// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

/// @notice Settlement strategies supported by the protocol.
library SettlementStrategy {
    /// @notice Strategies IDs supported.
    /// @param DATA_STREAMS_BASIC_FEED The strategy ID that uses basic reports from CL Data Streams.
    /// @param DATA_STREAMS_PREMIUM_FEED The strategy ID that uses premium reports from CL Data Streams.
    enum StrategyId {
        DATA_STREAMS_BASIC_FEED,
        // TODO: implement
        DATA_STREAMS_PREMIUM_FEED
    }

    /// @notice The {SettlementStrategy} namespace storage structure.
    /// @param strategyId The strategy id active.
    /// @param isEnabled Whether the strategy is enabled or not. May be used to pause trading in a market.
    /// @param strategyData Data structure required for the settlement strategy, varies for each strategy.
    struct Data {
        StrategyId strategyId;
        bool isEnabled;
        bytes strategyData;
    }

    /// @notice Data structure used by the {DATA_STREAMS_BASIC_FEED} strategy.
    /// @param streamId The Chainlink Data Streams stream id.
    /// @param feedLabel The Chainlink Data Streams feed label.
    /// @param queryLabel The Chainlink Data Streams query label.
    /// @param upkeep The address of the Chainlink Automation Upkeep contract used.
    /// @param settlementDelay The delay in seconds to wait for the settlement report.
    struct DataStreamsBasicFeed {
        string streamId;
        string feedLabel;
        string queryLabel;
        address upkeep;
        uint96 settlementDelay;
    }
}
