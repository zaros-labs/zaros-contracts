// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { SettlementStrategy } from "@zaros/markets/perps/storage/SettlementStrategy.sol";
import { BaseScript } from "./Base.s.sol";

contract CreatePerpsMarket is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    string internal constant DATA_STREAMS_FEED_LABEL = "feedIDs";
    string internal constant DATA_STREAMS_QUERY_LABEL = "timestamp";

    address internal defaultSettlementUpkeep;

    string internal ethUsdStreamId;

    uint128 internal constant ETH_USD_MARKET_ID = 1;
    string internal constant ETH_USD_MARKET_NAME = "ETH/USD Perpetual Futures";
    string internal constant ETH_USD_MARKET_SYMBOL = "ETH/USD PERP";
    uint128 internal constant ETH_USD_MMR = 0.01e18;
    uint128 internal constant ETH_USD_MAX_OI = 100_000_000e18;
    uint128 internal constant ETH_USD_MIN_IMR = 0.01e18;
    uint96 internal constant ETH_USD_SETTLEMENT_DELAY = 2 seconds;
    OrderFees.Data internal ethUsdOrderFee = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

    string internal linkUsdStreamId;

    uint128 internal constant LINK_USD_MARKET_ID = 2;
    string internal constant LINK_USD_MARKET_NAME = "LINK/USD Perpetual";
    string internal constant LINK_USD_MARKET_SYMBOL = "LINK/USD-PERP";
    uint128 internal constant LINK_USD_MMR = 0.01e18;
    uint128 internal constant LINK_USD_MAX_OI = 100_000_000e18;
    uint128 internal constant LINK_USD_MIN_IMR = 0.01e18;
    uint96 internal constant LINK_USD_SETTLEMENT_DELAY = 2 seconds;
    OrderFees.Data internal linkUsdOrderFee = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    PerpsEngine internal perpsEngine;

    function run() public broadcaster {
        defaultSettlementUpkeep = vm.envAddress("DEFAULT_SETTLEMENT_UPKEEP");

        ethUsdStreamId = vm.envString("ETH_USD_STREAM_ID");

        linkUsdStreamId = vm.envString("LINK_USD_STREAM_ID");

        perpsEngine = PerpsEngine(payable(address(vm.envAddress("PERPS_ENGINE"))));

        SettlementStrategy.DataStreamsBasicFeed memory ethUsdSettlementStrategyData = SettlementStrategy
            .DataStreamsBasicFeed({
            streamId: ethUsdStreamId,
            feedLabel: DATA_STREAMS_FEED_LABEL,
            queryLabel: DATA_STREAMS_QUERY_LABEL,
            upkeep: defaultSettlementUpkeep,
            settlementDelay: ETH_USD_SETTLEMENT_DELAY
        });
        SettlementStrategy.Data memory ethUsdSettlementStrategy = SettlementStrategy.Data({
            strategyId: SettlementStrategy.StrategyId.DATA_STREAMS_BASIC_FEED,
            isEnabled: true,
            strategyData: abi.encode(ethUsdSettlementStrategyData)
        });

        perpsEngine.createPerpsMarket(
            ETH_USD_MARKET_ID,
            ETH_USD_MARKET_NAME,
            ETH_USD_MARKET_SYMBOL,
            ETH_USD_MMR,
            ETH_USD_MAX_OI,
            ETH_USD_MIN_IMR,
            ethUsdSettlementStrategy,
            ethUsdOrderFee
        );

        SettlementStrategy.DataStreamsBasicFeed memory linkUsdSettlementStrategyData = SettlementStrategy
            .DataStreamsBasicFeed({
            streamId: linkUsdStreamId,
            feedLabel: DATA_STREAMS_FEED_LABEL,
            queryLabel: DATA_STREAMS_QUERY_LABEL,
            upkeep: defaultSettlementUpkeep,
            settlementDelay: LINK_USD_SETTLEMENT_DELAY
        });
        SettlementStrategy.Data memory linkUsdSettlementStrategy = SettlementStrategy.Data({
            strategyId: SettlementStrategy.StrategyId.DATA_STREAMS_BASIC_FEED,
            isEnabled: true,
            strategyData: abi.encode(linkUsdSettlementStrategyData)
        });

        perpsEngine.createPerpsMarket(
            LINK_USD_MARKET_ID,
            LINK_USD_MARKET_NAME,
            LINK_USD_MARKET_SYMBOL,
            LINK_USD_MMR,
            LINK_USD_MAX_OI,
            LINK_USD_MIN_IMR,
            linkUsdSettlementStrategy,
            linkUsdOrderFee
        );
    }
}
