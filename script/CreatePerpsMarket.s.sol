// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { SettlementStrategy } from "@zaros/markets/perps/storage/SettlementStrategy.sol";
import { BaseScript } from "./Base.s.sol";

// TODO: update limit order strategies
contract CreatePerpsMarket is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    string internal constant DATA_STREAMS_FEED_PARAM_KEY = "feedIDs";
    string internal constant DATA_STREAMS_TIME_PARAM_KEY = "timestamp";

    address internal defaultMarketOrderUpkeep;
    uint256 internal defaultSettlementFee;

    string internal ethUsdStreamId;

    uint128 internal constant ETH_USD_MARKET_ID = 1;
    string internal constant ETH_USD_MARKET_NAME = "ETH/USD Perpetual Futures";
    string internal constant ETH_USD_MARKET_SYMBOL = "ETH/USD PERP";
    uint128 internal constant ETH_USD_MMR = 0.01e18;
    uint128 internal constant ETH_USD_MAX_OI = 100_000_000e18;
    uint128 internal constant ETH_USD_MIN_IMR = 0.01e18;
    uint248 internal constant ETH_USD_SETTLEMENT_DELAY = 2 seconds;
    OrderFees.Data internal ethUsdOrderFee = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

    string internal linkUsdStreamId;

    uint128 internal constant LINK_USD_MARKET_ID = 2;
    string internal constant LINK_USD_MARKET_NAME = "LINK/USD Perpetual";
    string internal constant LINK_USD_MARKET_SYMBOL = "LINK/USD-PERP";
    uint128 internal constant LINK_USD_MMR = 0.01e18;
    uint128 internal constant LINK_USD_MAX_OI = 100_000_000e18;
    uint128 internal constant LINK_USD_MIN_IMR = 0.01e18;
    uint248 internal constant LINK_USD_SETTLEMENT_DELAY = 2 seconds;
    OrderFees.Data internal linkUsdOrderFee = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    PerpsEngine internal perpsEngine;

    function run() public broadcaster {
        defaultMarketOrderUpkeep = vm.envAddress("DEFAULT_MARKET_ORDER_UPKEEP");
        defaultSettlementFee = vm.envUint("DEFAULT_SETTLEMENT_FEE");

        ethUsdStreamId = vm.envString("ETH_USD_STREAM_ID");

        linkUsdStreamId = vm.envString("LINK_USD_STREAM_ID");

        perpsEngine = PerpsEngine(payable(address(vm.envAddress("PERPS_ENGINE"))));

        SettlementStrategy.DataStreamsStrategy memory ethUsdMarketOrderStrategyData = SettlementStrategy
            .DataStreamsStrategy({
            streamId: ethUsdStreamId,
            feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
            queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
            settlementDelay: ETH_USD_SETTLEMENT_DELAY,
            isPremium: false
        });
        SettlementStrategy.Data memory ethUsdMarketOrderStrategy = SettlementStrategy.Data({
            strategyId: SettlementStrategy.StrategyId.DATA_STREAMS,
            isEnabled: true,
            settlementFee: uint80(defaultSettlementFee),
            upkeep: defaultMarketOrderUpkeep,
            strategyData: abi.encode(ethUsdMarketOrderStrategyData)
        });
        SettlementStrategy.Data memory ethUsdLimitOrderStrategy = SettlementStrategy.Data({
            strategyId: SettlementStrategy.StrategyId.DATA_STREAMS,
            isEnabled: true,
            settlementFee: uint80(defaultSettlementFee),
            upkeep: defaultMarketOrderUpkeep,
            strategyData: abi.encode(ethUsdMarketOrderStrategyData)
        });

        perpsEngine.createPerpsMarket(
            ETH_USD_MARKET_ID,
            ETH_USD_MARKET_NAME,
            ETH_USD_MARKET_SYMBOL,
            ETH_USD_MMR,
            ETH_USD_MAX_OI,
            ETH_USD_MIN_IMR,
            ethUsdMarketOrderStrategy,
            ethUsdLimitOrderStrategy,
            ethUsdOrderFee
        );

        SettlementStrategy.DataStreamsStrategy memory linkUsdMarketOrderStrategyData = SettlementStrategy
            .DataStreamsStrategy({
            streamId: linkUsdStreamId,
            feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
            queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
            settlementDelay: LINK_USD_SETTLEMENT_DELAY,
            isPremium: false
        });
        SettlementStrategy.Data memory linkUsdMarketOrderStrategy = SettlementStrategy.Data({
            strategyId: SettlementStrategy.StrategyId.DATA_STREAMS,
            isEnabled: true,
            settlementFee: uint80(defaultSettlementFee),
            upkeep: defaultMarketOrderUpkeep,
            strategyData: abi.encode(linkUsdMarketOrderStrategyData)
        });

        SettlementStrategy.Data memory linkUsdLimitOrderStrategy = SettlementStrategy.Data({
            strategyId: SettlementStrategy.StrategyId.DATA_STREAMS,
            isEnabled: true,
            settlementFee: uint80(defaultSettlementFee),
            upkeep: defaultMarketOrderUpkeep,
            strategyData: abi.encode(linkUsdMarketOrderStrategyData)
        });

        perpsEngine.createPerpsMarket(
            LINK_USD_MARKET_ID,
            LINK_USD_MARKET_NAME,
            LINK_USD_MARKET_SYMBOL,
            LINK_USD_MMR,
            LINK_USD_MAX_OI,
            LINK_USD_MIN_IMR,
            linkUsdMarketOrderStrategy,
            linkUsdLimitOrderStrategy,
            linkUsdOrderFee
        );
    }
}
