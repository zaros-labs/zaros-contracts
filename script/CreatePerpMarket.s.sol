// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { LimitOrderUpkeep } from "@zaros/external/chainlink/upkeeps/limit-order/LimitOrderUpkeep.sol";
import { MarketOrderUpkeep } from "@zaros/external/chainlink/upkeeps/market-order/MarketOrderUpkeep.sol";
import { OcoOrderUpkeep } from "@zaros/external/chainlink/upkeeps/oco-order/OcoOrderUpkeep.sol";
import { LimitOrderSettlementStrategy } from "@zaros/markets/settlement/LimitOrderSettlementStrategy.sol";
import { MarketOrderSettlementStrategy } from "@zaros/markets/settlement/MarketOrderSettlementStrategy.sol";
import { OcoOrderSettlementStrategy } from "@zaros/markets/settlement/OcoOrderSettlementStrategy.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { IGlobalConfigurationModule } from "@zaros/markets/perps/interfaces/IGlobalConfigurationModule.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "./utils/ProtocolConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

// TODO: update limit order strategies
// TODO: Create isPremium protocol configurable variable
// TODO: update owner and forwarder on upkeep initialization
contract CreatePerpMarket is BaseScript, ProtocolConfiguration {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    IVerifierProxy internal chainlinkVerifier;

    address internal ethUsdPriceAdapter;
    string internal ethUsdStreamId;

    address internal linkUsdPriceAdapter;
    string internal linkUsdStreamId;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;

    EnumerableMap.UintToAddressMap internal limitOrderSettlementStrategies;
    EnumerableMap.UintToAddressMap internal marketOrderSettlementStrategies;
    EnumerableMap.UintToAddressMap internal ocoOrderSettlementStrategies;

    mapping(uint256 marketId => address[] upkeeps) internal limitOrderUpkeeps;
    mapping(uint256 marketId => address[] upkeeps) internal marketOrderUpkeeps;
    mapping(uint256 marketId => address[] upkeeps) internal ocoOrderUpkeeps;

    function run() public broadcaster {
        chainlinkVerifier = IVerifierProxy(vm.envAddress("CHAINLINK_VERIFIER"));

        ethUsdPriceAdapter = vm.envAddress("ETH_USD_PRICE_FEED");
        ethUsdStreamId = vm.envString("ETH_USD_STREAM_ID");

        linkUsdPriceAdapter = vm.envAddress("LINK_USD_PRICE_FEED");
        linkUsdStreamId = vm.envString("LINK_USD_STREAM_ID");

        perpsEngine = IPerpsEngine(payable(address(vm.envAddress("PERPS_ENGINE"))));

        SettlementConfiguration.DataStreamsMarketStrategy memory ethUsdMarketOrderConfigurationData =
        SettlementConfiguration.DataStreamsMarketStrategy({
            chainlinkVerifier: chainlinkVerifier,
            streamId: ethUsdStreamId,
            feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
            queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
            settlementDelay: ETH_USD_SETTLEMENT_DELAY,
            isPremium: ETH_USD_IS_PREMIUM_FEED
        });

        deploySettlementStrategies();
        deployKeepers();
        configureKeepers();

        // TODO: Add price adapter
        SettlementConfiguration.Data memory ethUsdMarketOrderConfiguration = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_MARKET,
            isEnabled: true,
            fee: DEFAULT_SETTLEMENT_FEE,
            settlementStrategy: marketOrderSettlementStrategies.get(ETH_USD_MARKET_ID),
            data: abi.encode(ethUsdMarketOrderConfigurationData)
        });
        SettlementConfiguration.Data memory ethUsdLimitOrderConfiguration = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_CUSTOM,
            isEnabled: true,
            fee: DEFAULT_SETTLEMENT_FEE,
            settlementStrategy: limitOrderSettlementStrategies.get(ETH_USD_MARKET_ID),
            data: abi.encode(ethUsdMarketOrderConfigurationData)
        });

        SettlementConfiguration.Data[] memory ethUsdCustomOrderStrategies = new SettlementConfiguration.Data[](1);
        ethUsdCustomOrderStrategies[0] = ethUsdLimitOrderConfiguration;

        perpsEngine.createPerpMarket({
            params: IGlobalConfigurationModule.CreatePerpMarketParams({
                marketId: ETH_USD_MARKET_ID,
                name: ETH_USD_MARKET_NAME,
                symbol: ETH_USD_MARKET_SYMBOL,
                priceAdapter: ethUsdPriceAdapter,
                initialMarginRateX18: ETH_USD_IMR,
                maintenanceMarginRateX18: ETH_USD_MMR,
                maxOpenInterest: ETH_USD_MAX_OI,
                maxFundingVelocity: ETH_USD_MAX_FUNDING_VELOCITY,
                skewScale: ETH_USD_SKEW_SCALE,
                minTradeSizeX18: ETH_USD_MIN_TRADE_SIZE,
                marketOrderConfiguration: ethUsdMarketOrderConfiguration,
                customTriggerStrategies: ethUsdCustomOrderStrategies,
                orderFees: ethUsdOrderFees
            })
        });

        SettlementConfiguration.DataStreamsMarketStrategy memory linkUsdMarketOrderConfigurationData =
        SettlementConfiguration.DataStreamsMarketStrategy({
            // TODO: Add price adapter
            chainlinkVerifier: chainlinkVerifier,
            streamId: linkUsdStreamId,
            feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
            queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
            settlementDelay: LINK_USD_SETTLEMENT_DELAY,
            isPremium: LINK_USD_IS_PREMIUM_FEED
        });

        // TODO: Add price adapter
        SettlementConfiguration.Data memory linkUsdMarketOrderConfiguration = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_MARKET,
            isEnabled: true,
            fee: DEFAULT_SETTLEMENT_FEE,
            settlementStrategy: marketOrderSettlementStrategies.get(LINK_USD_MARKET_ID),
            data: abi.encode(linkUsdMarketOrderConfigurationData)
        });

        SettlementConfiguration.Data memory linkUsdLimitOrderConfiguration = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_CUSTOM,
            isEnabled: true,
            fee: DEFAULT_SETTLEMENT_FEE,
            settlementStrategy: limitOrderSettlementStrategies.get(LINK_USD_MARKET_ID),
            data: abi.encode(linkUsdMarketOrderConfigurationData)
        });

        SettlementConfiguration.Data[] memory linkUsdCustomOrderStrategies = new SettlementConfiguration.Data[](1);
        linkUsdCustomOrderStrategies[0] = linkUsdLimitOrderConfiguration;

        perpsEngine.createPerpMarket({
            params: IGlobalConfigurationModule.CreatePerpMarketParams({
                marketId: LINK_USD_MARKET_ID,
                name: LINK_USD_MARKET_NAME,
                symbol: LINK_USD_MARKET_SYMBOL,
                priceAdapter: linkUsdPriceAdapter,
                initialMarginRateX18: LINK_USD_IMR,
                maintenanceMarginRateX18: LINK_USD_MMR,
                maxOpenInterest: LINK_USD_MAX_OI,
                maxFundingVelocity: LINK_USD_MAX_FUNDING_VELOCITY,
                skewScale: LINK_USD_SKEW_SCALE,
                minTradeSizeX18: LINK_USD_MIN_TRADE_SIZE,
                marketOrderConfiguration: linkUsdMarketOrderConfiguration,
                customTriggerStrategies: linkUsdCustomOrderStrategies,
                orderFees: linkUsdOrderFees
            })
        });
    }

    function deploySettlementStrategies() internal {
        address limitOrderSettlementStrategyImplementation = address(new LimitOrderSettlementStrategy());

        console.log("Limit Order Settlement Strategy Implementation: ", limitOrderSettlementStrategyImplementation);

        address marketOrderSettlementStrategyImplementation = address(new MarketOrderSettlementStrategy());

        console.log("Market Order Settlement Strategy Implementation: ", marketOrderSettlementStrategyImplementation);

        address ocoOrderSettlementStrategyImplementation = address(new OcoOrderSettlementStrategy());

        console.log("Oco Order Settlement Strategy Implementation: ", ocoOrderSettlementStrategyImplementation);

        bytes memory ethUsdLimitOrderSettlementStrategyInitializeData = abi.encodeWithSelector(
            LimitOrderSettlementStrategy.initialize.selector,
            perpsEngine,
            ETH_USD_MARKET_ID,
            LIMIT_ORDER_SETTLEMENT_ID,
            MAX_ACTIVE_LIMIT_ORDERS_PER_ACCOUNT_PER_MARKET
        );
        bytes memory ethUsdMarketOrderSettlementStrategyInitializeData =
            abi.encodeWithSelector(MarketOrderSettlementStrategy.initialize.selector, perpsEngine, ETH_USD_MARKET_ID);
        bytes memory ethUsdOcoOrderSettlementStrategyInitializeData = abi.encodeWithSelector(
            OcoOrderSettlementStrategy.initialize.selector, perpsEngine, ETH_USD_MARKET_ID, OCO_ORDER_SETTLEMENT_ID
        );

        bytes memory linkUsdLimitOrderSettlementStrategyInitializeData = abi.encodeWithSelector(
            LimitOrderSettlementStrategy.initialize.selector,
            perpsEngine,
            LINK_USD_MARKET_ID,
            LIMIT_ORDER_SETTLEMENT_ID,
            MAX_ACTIVE_LIMIT_ORDERS_PER_ACCOUNT_PER_MARKET
        );
        bytes memory linkUsdMarketOrderSettlementStrategyInitializeData =
            abi.encodeWithSelector(MarketOrderSettlementStrategy.initialize.selector, perpsEngine, LINK_USD_MARKET_ID);
        bytes memory linkUsdOcoOrderSettlementStrategyInitializeData = abi.encodeWithSelector(
            OcoOrderSettlementStrategy.initialize.selector, perpsEngine, LINK_USD_MARKET_ID, OCO_ORDER_SETTLEMENT_ID
        );

        address ethUsdLimitOrderSettlementStrategy = address(
            new ERC1967Proxy(
                limitOrderSettlementStrategyImplementation, ethUsdLimitOrderSettlementStrategyInitializeData
            )
        );

        console.log("ETH-USD Limit Order Settlement Strategy: ", ethUsdLimitOrderSettlementStrategy);

        limitOrderSettlementStrategies.set(ETH_USD_MARKET_ID, ethUsdLimitOrderSettlementStrategy);

        address ethUsdMarketOrderSettlementStrategy = address(
            new ERC1967Proxy(
                marketOrderSettlementStrategyImplementation, ethUsdMarketOrderSettlementStrategyInitializeData
            )
        );

        console.log("ETH-USD Market Order Settlement Strategy: ", ethUsdMarketOrderSettlementStrategy);

        marketOrderSettlementStrategies.set(ETH_USD_MARKET_ID, ethUsdMarketOrderSettlementStrategy);

        address ethUsdOcoOrderSettlementStrategy = address(
            new ERC1967Proxy(ocoOrderSettlementStrategyImplementation, ethUsdOcoOrderSettlementStrategyInitializeData)
        );

        console.log("ETH-USD Oco Order Settlement Strategy: ", ethUsdOcoOrderSettlementStrategy);

        ocoOrderSettlementStrategies.set(ETH_USD_MARKET_ID, ethUsdOcoOrderSettlementStrategy);

        address linkUsdLimitOrderSettlementStrategy = address(
            new ERC1967Proxy(
                limitOrderSettlementStrategyImplementation, linkUsdLimitOrderSettlementStrategyInitializeData
            )
        );

        console.log("LINK-USD Limit OrderSettlement Strategy: ", linkUsdLimitOrderSettlementStrategy);

        limitOrderSettlementStrategies.set(LINK_USD_MARKET_ID, linkUsdLimitOrderSettlementStrategy);

        address linkUsdMarketOrderSettlementStrategy = address(
            new ERC1967Proxy(
                marketOrderSettlementStrategyImplementation, linkUsdMarketOrderSettlementStrategyInitializeData
            )
        );

        console.log("LINK-USD Market Order Settlement Strategy: ", linkUsdMarketOrderSettlementStrategy);

        marketOrderSettlementStrategies.set(LINK_USD_MARKET_ID, linkUsdMarketOrderSettlementStrategy);

        address linkUsdOcoOrderSettlementStrategy = address(
            new ERC1967Proxy(
                ocoOrderSettlementStrategyImplementation, linkUsdOcoOrderSettlementStrategyInitializeData
            )
        );

        console.log("LINK-USD Oco Order Settlement Strategy: ", linkUsdOcoOrderSettlementStrategy);

        ocoOrderSettlementStrategies.set(LINK_USD_MARKET_ID, linkUsdOcoOrderSettlementStrategy);
    }

    function deployKeepers() internal {
        address limitOrderUpkeepImplementation = address(new LimitOrderUpkeep());

        console.log("LimitOrderUpkeep Implementation: ", limitOrderUpkeepImplementation);

        address marketOrderUpkeepImplementation = address(new MarketOrderUpkeep());

        console.log("MarketOrderUpkeep Implementation: ", marketOrderUpkeepImplementation);

        address ocoOrderUpkeepImplementation = address(new OcoOrderUpkeep());

        console.log("OcoOrderUpkeep Implementation: ", ocoOrderUpkeepImplementation);

        uint256[] memory limitOrderMarketIds = limitOrderSettlementStrategies.keys();
        uint256[] memory marketOrderMarketIds = marketOrderSettlementStrategies.keys();
        uint256[] memory ocoOrderMarketIds = ocoOrderSettlementStrategies.keys();

        for (uint256 i = 0; i < limitOrderMarketIds.length; i++) {
            uint256 marketId = limitOrderMarketIds[i];
            address limitOrderUpkeep = address(
                new ERC1967Proxy(
                    limitOrderUpkeepImplementation,
                    abi.encodeWithSelector(
                        LimitOrderUpkeep.initialize.selector, deployer, limitOrderSettlementStrategies.get(marketId)
                    )
                )
            );

            console.log("LimitOrderUpkeep: ", limitOrderUpkeep);

            limitOrderUpkeeps[marketId].push(limitOrderUpkeep);
        }

        for (uint256 i = 0; i < marketOrderMarketIds.length; i++) {
            uint256 marketId = marketOrderMarketIds[i];
            address marketOrderUpkeep = address(
                new ERC1967Proxy(
                    marketOrderUpkeepImplementation,
                    abi.encodeWithSelector(
                        MarketOrderUpkeep.initialize.selector, deployer, marketOrderSettlementStrategies.get(marketId)
                    )
                )
            );

            console.log("MarketOrderUpkeep: ", marketOrderUpkeep);

            marketOrderUpkeeps[marketId].push(marketOrderUpkeep);
        }

        for (uint256 i = 0; i < ocoOrderMarketIds.length; i++) {
            uint256 marketId = ocoOrderMarketIds[i];
            address ocoOrderUpkeep = address(
                new ERC1967Proxy(
                    ocoOrderUpkeepImplementation,
                    abi.encodeWithSelector(
                        OcoOrderUpkeep.initialize.selector, deployer, ocoOrderSettlementStrategies.get(marketId)
                    )
                )
            );

            console.log("OcoOrderUpkeep: ", ocoOrderUpkeep);

            ocoOrderUpkeeps[marketId].push(ocoOrderUpkeep);
        }
    }

    function configureKeepers() internal {
        LimitOrderSettlementStrategy ethUsdLimitOrderSettlementStrategy =
            LimitOrderSettlementStrategy(limitOrderSettlementStrategies.get(ETH_USD_MARKET_ID));
        MarketOrderSettlementStrategy ethUsdMarketOrderSettlementStrategy =
            MarketOrderSettlementStrategy(marketOrderSettlementStrategies.get(ETH_USD_MARKET_ID));
        OcoOrderSettlementStrategy ethUsOcoOrderSettlementStrategy =
            OcoOrderSettlementStrategy(ocoOrderSettlementStrategies.get(ETH_USD_MARKET_ID));

        LimitOrderSettlementStrategy linkUsdLimitOrderSettlementStrategy =
            LimitOrderSettlementStrategy(limitOrderSettlementStrategies.get(LINK_USD_MARKET_ID));
        MarketOrderSettlementStrategy linkUsdMarketOrderSettlementStrategy =
            MarketOrderSettlementStrategy(marketOrderSettlementStrategies.get(LINK_USD_MARKET_ID));
        OcoOrderSettlementStrategy linkUsdOcoOrderSettlementStrategy =
            OcoOrderSettlementStrategy(ocoOrderSettlementStrategies.get(LINK_USD_MARKET_ID));

        ethUsdLimitOrderSettlementStrategy.setKeepers(limitOrderUpkeeps[ETH_USD_MARKET_ID]);
        ethUsdMarketOrderSettlementStrategy.setKeepers(marketOrderUpkeeps[ETH_USD_MARKET_ID]);
        ethUsOcoOrderSettlementStrategy.setKeepers(ocoOrderUpkeeps[ETH_USD_MARKET_ID]);

        linkUsdLimitOrderSettlementStrategy.setKeepers(limitOrderUpkeeps[LINK_USD_MARKET_ID]);
        linkUsdMarketOrderSettlementStrategy.setKeepers(marketOrderUpkeeps[LINK_USD_MARKET_ID]);
        linkUsdOcoOrderSettlementStrategy.setKeepers(ocoOrderUpkeeps[LINK_USD_MARKET_ID]);

        console.log("All Keepers have been configured.");
    }
}
