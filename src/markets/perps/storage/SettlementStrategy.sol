// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

/// @notice Settlement strategies supported by the protocol.
library SettlementStrategy {
    /// @notice Constant base domain used to access a given SettlementStrategy's storage slot.
    string internal constant SETTLEMENT_STRATEGY_DOMAIN = "fi.zaros.markets.PerpsMarket.SettlementStrategy";

    /// @notice Strategies IDs supported.
    /// @param DATA_STREAMS The strategy ID that uses basic or premium reports from CL Data Streams to settle
    /// market orders.
    enum StrategyType { DATA_STREAMS }

    /// @notice The {SettlementStrategy} namespace storage structure.
    /// @param strategyType The strategy id active.
    /// @param isEnabled Whether the strategy is enabled or not. May be used to pause trading in a market.
    /// @param settlementFee The settlement cost in USD charged from the trader.
    /// @param upkeep The address of the responsible Upkeep contract (address(0) means anyone can settle).
    /// @param strategyData Data structure required for the settlement strategy, varies for each strategy.
    struct Data {
        StrategyType strategyType;
        bool isEnabled;
        uint80 settlementFee;
        address upkeep;
        bytes strategyData;
    }

    /// @notice Data structure used by the {DATA_STREAMS} strategy.
    /// @param streamId The Chainlink Data Streams stream id.
    /// @param feedLabel The Chainlink Data Streams feed label.
    /// @param queryLabel The Chainlink Data Streams query label.
    /// @param settlementDelay The delay in seconds to wait for the settlement report.
    struct DataStreamsMarketStrategy {
        string streamId;
        string feedLabel;
        string queryLabel;
        uint248 settlementDelay;
        bool isPremium;
    }

    struct DataStreamsCustomStrategy {
        string streamId;
        string feedLabel;
        string queryLabel;
        bool isPremium;
    }

    /// @dev The market order strategy id is always 0.
    function load(uint128 marketId, uint128 strategyId) internal pure returns (Data storage strategy) {
        bytes32 slot = keccak256(abi.encode(SETTLEMENT_STRATEGY_DOMAIN, marketId, strategyId));
        assembly {
            strategy.slot := slot
        }
    }

    function create(uint128 marketId, uint128 strategyId, Data memory strategy) internal {
        bytes32 slot = keccak256(abi.encode(SETTLEMENT_STRATEGY_DOMAIN, marketId, strategyId));
        assembly {
            sstore(slot, strategy.slot)
        }
    }
}
