// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { CreatePerpMarketParams } from "@zaros/markets/perps/interfaces/IGlobalConfigurationModule.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { BaseScript } from "./Base.s.sol";

// TODO: update limit order strategies
contract CreatePerpMarket is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    string internal constant DATA_STREAMS_FEED_PARAM_KEY = "feedIDs";
    string internal constant DATA_STREAMS_TIME_PARAM_KEY = "timestamp";

    IVerifierProxy internal chainlinkVerifier;
    address internal defaultMarketOrderSettlementStrategy;
    address internal defaultMarketOrderUpkeep;
    uint256 internal defaultSettlementFee;

    address internal ethUsdPriceAdapter;
    string internal ethUsdStreamId;

    uint128 internal constant ETH_USD_MARKET_ID = 1;
    string internal constant ETH_USD_MARKET_NAME = "ETH/USD Perpetual Futures";
    string internal constant ETH_USD_MARKET_SYMBOL = "ETH/USD PERP";
    uint128 internal constant ETH_USD_MIN_IMR = 0.01e18;
    uint128 internal constant ETH_USD_MMR = 0.01e18;
    uint128 internal constant ETH_USD_MAX_OI = 100_000_000e18;
    uint256 internal constant ETH_USD_SKEW_SCALE = 1_000_000e18;
    uint128 internal constant ETH_USD_MAX_FUNDING_VELOCITY = 0.25e18;
    uint248 internal constant ETH_USD_SETTLEMENT_DELAY = 2 seconds;
    OrderFees.Data internal ethUsdOrderFee = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

    address internal linkUsdPriceAdapter;
    string internal linkUsdStreamId;

    uint128 internal constant LINK_USD_MARKET_ID = 2;
    string internal constant LINK_USD_MARKET_NAME = "LINK/USD Perpetual";
    string internal constant LINK_USD_MARKET_SYMBOL = "LINK/USD-PERP";
    uint128 internal constant LINK_USD_MIN_IMR = 0.01e18;
    uint128 internal constant LINK_USD_MMR = 0.01e18;
    uint128 internal constant LINK_USD_MAX_OI = 100_000_000e18;
    uint256 internal constant LINK_USD_SKEW_SCALE = 1_000_000e18;
    uint128 internal constant LINK_USD_MAX_FUNDING_VELOCITY = 0.25e18;
    uint248 internal constant LINK_USD_SETTLEMENT_DELAY = 2 seconds;
    OrderFees.Data internal linkUsdOrderFee = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        chainlinkVerifier = IVerifierProxy(vm.envAddress("CHAINLINK_VERIFIER"));
        defaultMarketOrderSettlementStrategy = vm.envAddress("DEFAULT_MARKET_ORDER_SETTLEMENT_STRATEGY");
        defaultMarketOrderUpkeep = vm.envAddress("DEFAULT_MARKET_ORDER_UPKEEP");
        defaultSettlementFee = vm.envUint("DEFAULT_SETTLEMENT_FEE");

        ethUsdPriceAdapter = vm.envAddress("ETH_USD_PRICE_FEED");
        ethUsdStreamId = vm.envString("ETH_USD_STREAM_ID");

        linkUsdPriceAdapter = vm.envAddress("LINK_USD_PRICE_FEED");
        linkUsdStreamId = vm.envString("LINK_USD_STREAM_ID");

        perpsEngine = IPerpsEngine(payable(address(vm.envAddress("PERPS_ENGINE"))));

        SettlementConfiguration.DataStreamsMarketStrategy memory ethUsdMarketOrderStrategyData =
        SettlementConfiguration.DataStreamsMarketStrategy({
            chainlinkVerifier: chainlinkVerifier,
            streamId: ethUsdStreamId,
            feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
            queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
            settlementDelay: ETH_USD_SETTLEMENT_DELAY,
            isPremium: false
        });

        // TODO: Add price adapter
        SettlementConfiguration.Data memory ethUsdMarketOrderStrategy = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_MARKET,
            isEnabled: true,
            fee: uint80(defaultSettlementFee),
            settlementStrategy: defaultMarketOrderSettlementStrategy,
            data: abi.encode(ethUsdMarketOrderStrategyData)
        });
        SettlementConfiguration.Data memory ethUsdLimitOrderStrategy = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_CUSTOM,
            isEnabled: true,
            fee: uint80(defaultSettlementFee),
            settlementStrategy: defaultMarketOrderSettlementStrategy,
            data: abi.encode(ethUsdMarketOrderStrategyData)
        });

        SettlementConfiguration.Data[] memory ethUsdCustomTriggerStrategies = new SettlementConfiguration.Data[](1);
        ethUsdCustomTriggerStrategies[0] = ethUsdLimitOrderStrategy;

        perpsEngine.createPerpMarket({
            params: CreatePerpMarketParams({
                marketId: uint128(ETH_USD_MARKET_ID),
                name: ETH_USD_MARKET_NAME,
                symbol: ETH_USD_MARKET_SYMBOL,
                priceAdapter: ethUsdPriceAdapter,
                minInitialMarginRateX18: ETH_USD_MIN_IMR,
                maintenanceMarginRateX18: ETH_USD_MMR,
                maxOpenInterest: ETH_USD_MAX_OI,
                skewScale: ETH_USD_SKEW_SCALE,
                maxFundingVelocity: ETH_USD_MAX_FUNDING_VELOCITY,
                marketOrderStrategy: ethUsdMarketOrderStrategy,
                customTriggerStrategies: ethUsdCustomTriggerStrategies,
                orderFees: ethUsdOrderFee
            })
        });

        SettlementConfiguration.DataStreamsMarketStrategy memory linkUsdMarketOrderStrategyData =
        SettlementConfiguration.DataStreamsMarketStrategy({
            // TODO: Add price adapter
            chainlinkVerifier: chainlinkVerifier,
            streamId: linkUsdStreamId,
            feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
            queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
            settlementDelay: LINK_USD_SETTLEMENT_DELAY,
            isPremium: false
        });

        // TODO: Add price adapter
        SettlementConfiguration.Data memory linkUsdMarketOrderStrategy = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_MARKET,
            isEnabled: true,
            fee: uint80(defaultSettlementFee),
            settlementStrategy: defaultMarketOrderSettlementStrategy,
            data: abi.encode(linkUsdMarketOrderStrategyData)
        });

        SettlementConfiguration.Data memory linkUsdLimitOrderStrategy = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_CUSTOM,
            isEnabled: true,
            fee: uint80(defaultSettlementFee),
            settlementStrategy: defaultMarketOrderSettlementStrategy,
            data: abi.encode(linkUsdMarketOrderStrategyData)
        });

        SettlementConfiguration.Data[] memory linkUsdCustomTriggerStrategies = new SettlementConfiguration.Data[](1);
        linkUsdCustomTriggerStrategies[0] = linkUsdLimitOrderStrategy;

        perpsEngine.createPerpMarket({
            params: CreatePerpMarketParams({
                marketId: uint128(LINK_USD_MARKET_ID),
                name: LINK_USD_MARKET_NAME,
                symbol: LINK_USD_MARKET_SYMBOL,
                priceAdapter: linkUsdPriceAdapter,
                minInitialMarginRateX18: LINK_USD_MIN_IMR,
                maintenanceMarginRateX18: LINK_USD_MMR,
                maxOpenInterest: LINK_USD_MAX_OI,
                skewScale: LINK_USD_SKEW_SCALE,
                maxFundingVelocity: LINK_USD_MAX_FUNDING_VELOCITY,
                marketOrderStrategy: linkUsdMarketOrderStrategy,
                customTriggerStrategies: linkUsdCustomTriggerStrategies,
                orderFees: linkUsdOrderFee
            })
        });
    }
}
