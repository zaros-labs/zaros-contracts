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
import { CreatePerpMarketParams } from "@zaros/markets/perps/interfaces/IGlobalConfigurationModule.sol";
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
contract CreatePerpMarket is BaseScript, ProtocolConfiguration {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    IVerifierProxy internal chainlinkVerifier;

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

        perpsEngine = IPerpsEngine(payable(address(vm.envAddress("PERPS_ENGINE"))));

        (MarketConfig[] memory marketsConfig) = getMarketsConfig();

        deploySettlementStrategies(marketsConfig);
        deployKeepers();
        configureKeepers(marketsConfig);

        for (uint256 i = 0; i < marketsConfig.length; i++) {

            SettlementConfiguration.DataStreamsMarketStrategy memory marketOrderConfigurationData =
            SettlementConfiguration.DataStreamsMarketStrategy({
                chainlinkVerifier: chainlinkVerifier,
                streamId: marketsConfig[i].streamId,
                feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
                queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
                settlementDelay: marketsConfig[i].settlementDelay,
                isPremium: false
            });

            // TODO: Add price adapter
            SettlementConfiguration.Data memory marketOrderConfiguration = SettlementConfiguration.Data({
                strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_MARKET,
                isEnabled: true,
                fee: DEFAULT_SETTLEMENT_FEE,
                settlementStrategy: marketOrderSettlementStrategies.get(marketsConfig[i].marketId),
                data: abi.encode(marketOrderConfigurationData)
            });

            SettlementConfiguration.Data memory limitOrderConfiguration = SettlementConfiguration.Data({
                strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_CUSTOM,
                isEnabled: true,
                fee: DEFAULT_SETTLEMENT_FEE,
                settlementStrategy: limitOrderSettlementStrategies.get(marketsConfig[i].marketId),
                data: abi.encode(marketOrderConfigurationData)
            });

            SettlementConfiguration.Data[] memory customOrderStrategies = new SettlementConfiguration.Data[](1);
            customOrderStrategies[0] = limitOrderConfiguration;

            perpsEngine.createPerpMarket({
                params: CreatePerpMarketParams({
                    marketId: marketsConfig[i].marketId,
                    name: marketsConfig[i].marketName,
                    symbol: marketsConfig[i].marketSymbol,
                    priceAdapter: marketsConfig[i].priceAdapter,
                    initialMarginRateX18: marketsConfig[i].imr,
                    maintenanceMarginRateX18: marketsConfig[i].mmr,
                    maxOpenInterest: marketsConfig[i].maxOi,
                    skewScale: marketsConfig[i].skewScale,
                    maxFundingVelocity: marketsConfig[i].maxFundingVelocity,
                    marketOrderConfiguration: marketOrderConfiguration,
                    customTriggerStrategies: customOrderStrategies,
                    orderFees: marketsConfig[i].orderFees
                })
            });

        }
    }

     function getMarketsConfig() internal view returns(MarketConfig[] memory){

        MarketConfig[] memory marketsConfig = new MarketConfig[](2);

        MarketConfig memory ethUsdConfig = MarketConfig({
            marketId: ETH_USD_MARKET_ID,
            marketName: ETH_USD_MARKET_NAME,
            marketSymbol: ETH_USD_MARKET_SYMBOL,
            imr: ETH_USD_IMR,
            mmr: ETH_USD_MMR,
            marginRequirements: ETH_USD_MARGIN_REQUIREMENTS,
            maxOi: ETH_USD_MAX_OI,
            skewScale: ETH_USD_SKEW_SCALE,
            maxFundingVelocity: ETH_USD_MAX_FUNDING_VELOCITY,
            settlementDelay: ETH_USD_SETTLEMENT_DELAY,
            priceAdapter: vm.envAddress("ETH_USD_PRICE_FEED"),
            streamId: vm.envString("ETH_USD_STREAM_ID"),
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });
        marketsConfig[0] = ethUsdConfig;

        MarketConfig memory linkUsdConfig = MarketConfig({
            marketId: LINK_USD_MARKET_ID,
            marketName: LINK_USD_MARKET_NAME,
            marketSymbol: LINK_USD_MARKET_SYMBOL,
            imr: LINK_USD_IMR,
            mmr: LINK_USD_MMR,
            marginRequirements: LINK_USD_MARGIN_REQUIREMENTS,
            maxOi: LINK_USD_MAX_OI,
            skewScale: LINK_USD_SKEW_SCALE,
            maxFundingVelocity: LINK_USD_MAX_FUNDING_VELOCITY,
            settlementDelay: LINK_USD_SETTLEMENT_DELAY,
            priceAdapter: vm.envAddress("LINK_USD_PRICE_FEED"),
            streamId: vm.envString("LINK_USD_STREAM_ID"),
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });
        marketsConfig[1] = linkUsdConfig;

        return marketsConfig;
    }

    function deploySettlementStrategies(MarketConfig[] memory marketsConfig) internal {
        address limitOrderSettlementStrategyImplementation = address(new LimitOrderSettlementStrategy());
        address marketOrderSettlementStrategyImplementation = address(new MarketOrderSettlementStrategy());
        address ocoOrderSettlementStrategyImplementation = address(new OcoOrderSettlementStrategy());

        console.log("----------");
        console.log("Limit Order Settlement Strategy Implementation: ", limitOrderSettlementStrategyImplementation);
        console.log("Market Order Settlement Strategy Implementation: ", marketOrderSettlementStrategyImplementation);
        console.log("Oco Order Settlement Strategy Implementation: ", ocoOrderSettlementStrategyImplementation);

        for (uint256 i = 0; i < marketsConfig.length; i++) {
            bytes memory LimitOrderSettlementStrategyInitializeData = abi.encodeWithSelector(
                LimitOrderSettlementStrategy.initialize.selector,
                perpsEngine,
                marketsConfig[i].marketId,
                LIMIT_ORDER_SETTLEMENT_ID,
                MAX_ACTIVE_LIMIT_ORDERS_PER_ACCOUNT_PER_MARKET
            );
            bytes memory MarketOrderSettlementStrategyInitializeData =
                abi.encodeWithSelector(MarketOrderSettlementStrategy.initialize.selector, perpsEngine, marketsConfig[i].marketId);
            bytes memory ocoOrderSettlementStrategyInitializeData = abi.encodeWithSelector(
                OcoOrderSettlementStrategy.initialize.selector, perpsEngine, marketsConfig[i].marketId, OCO_ORDER_SETTLEMENT_ID
            );

            address limitOrderSettlementStrategy = address(
                new ERC1967Proxy(
                    limitOrderSettlementStrategyImplementation, LimitOrderSettlementStrategyInitializeData
                )
            );

            limitOrderSettlementStrategies.set(marketsConfig[i].marketId, limitOrderSettlementStrategy);

            address marketOrderSettlementStrategy = address(
                new ERC1967Proxy(
                    marketOrderSettlementStrategyImplementation, MarketOrderSettlementStrategyInitializeData
                )
            );

            marketOrderSettlementStrategies.set(marketsConfig[i].marketId, marketOrderSettlementStrategy);

            address ocoOrderSettlementStrategy = address(
                new ERC1967Proxy(ocoOrderSettlementStrategyImplementation, ocoOrderSettlementStrategyInitializeData)
            );

            ocoOrderSettlementStrategies.set(marketsConfig[i].marketId, ocoOrderSettlementStrategy);

            console.log("----------");
            console.log(marketsConfig[i].marketSymbol, " Limit Order Settlement Strategy: ", limitOrderSettlementStrategy);
            console.log(marketsConfig[i].marketSymbol, " Market Order Settlement Strategy: ", marketOrderSettlementStrategy);
            console.log(marketsConfig[i].marketSymbol, " Oco Order Settlement Strategy: ", ocoOrderSettlementStrategy);
        }

    }

    function deployKeepers() internal {
        address limitOrderUpkeepImplementation = address(new LimitOrderUpkeep());
        address marketOrderUpkeepImplementation = address(new MarketOrderUpkeep());
        address ocoOrderUpkeepImplementation = address(new OcoOrderUpkeep());

        console.log("----------");
        console.log("LimitOrderUpkeep Implementation: ", limitOrderUpkeepImplementation);
        console.log("MarketOrderUpkeep Implementation: ", marketOrderUpkeepImplementation);
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

    function configureKeepers(MarketConfig[] memory marketsConfig) internal {

        for (uint256 i = 0; i < marketsConfig.length; i++) {
            LimitOrderSettlementStrategy limitOrderSettlementStrategy =
                LimitOrderSettlementStrategy(limitOrderSettlementStrategies.get(marketsConfig[i].marketId));

            MarketOrderSettlementStrategy marketOrderSettlementStrategy =
                MarketOrderSettlementStrategy(marketOrderSettlementStrategies.get(marketsConfig[i].marketId));

            OcoOrderSettlementStrategy ocoOrderSettlementStrategy =
                OcoOrderSettlementStrategy(ocoOrderSettlementStrategies.get(marketsConfig[i].marketId));

            limitOrderSettlementStrategy.setKeepers(limitOrderUpkeeps[marketsConfig[i].marketId]);
            marketOrderSettlementStrategy.setKeepers(marketOrderUpkeeps[marketsConfig[i].marketId]);
            ocoOrderSettlementStrategy.setKeepers(ocoOrderUpkeeps[marketsConfig[i].marketId]);
        }

        console.log("----------");
        console.log("All Keepers have been configured.");
    }
}
