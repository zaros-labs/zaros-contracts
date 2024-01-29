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

// Open Zeppelin dependencies
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// TODO: update limit order strategies
contract CreatePerpMarket is BaseScript {
    using EnumerableMap for EnumerableMap.UintToAddressMap;

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

    uint256 internal constant LIMIT_ORDER_SETTLEMENT_ID = 1;
    uint256 internal constant OCO_ORDER_SETTLEMENT_ID = 2;

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

    EnumerableMap.UintToAddressMap internal limitOrderSettlementStrategies;
    EnumerableMap.UintToAddressMap internal marketOrderSettlementStrategies;
    EnumerableMap.UintToAddressMap internal ocoOrderSettlementStrategies;

    mapping(uint256 marketId => address[] upkeeps) internal limitOrderUpkeeps;
    mapping(uint256 marketId => address[] upkeeps) internal marketOrderUpkeeps;
    mapping(uint256 marketId => address[] upkeeps) internal ocoOrderUpkeeps;

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

        SettlementConfiguration.DataStreamsMarketStrategy memory ethUsdMarketOrderConfigurationData =
        SettlementConfiguration.DataStreamsMarketStrategy({
            chainlinkVerifier: chainlinkVerifier,
            streamId: ethUsdStreamId,
            feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
            queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
            settlementDelay: ETH_USD_SETTLEMENT_DELAY,
            isPremium: false
        });

        deploySettlementStrategies();
        deployAndConfigureKeepers();

        // TODO: Add price adapter
        SettlementConfiguration.Data memory ethUsdMarketOrderConfiguration = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_MARKET,
            isEnabled: true,
            fee: uint80(defaultSettlementFee),
            settlementStrategy: marketOrderSettlementStrategies.get(ETH_USD_MARKET_ID),
            data: abi.encode(ethUsdMarketOrderConfigurationData)
        });
        SettlementConfiguration.Data memory ethUsdLimitOrderConfiguration = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_CUSTOM,
            isEnabled: true,
            fee: uint80(defaultSettlementFee),
            settlementStrategy: limitOrderSettlementStrategies.get(ETH_USD_MARKET_ID),
            data: abi.encode(ethUsdMarketOrderConfigurationData)
        });

        SettlementConfiguration.Data[] memory ethUsdCustomTriggerStrategies = new SettlementConfiguration.Data[](1);
        ethUsdCustomTriggerStrategies[0] = ethUsdLimitOrderConfiguration;

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
                marketOrderConfiguration: ethUsdMarketOrderConfiguration,
                customTriggerStrategies: ethUsdCustomTriggerStrategies,
                orderFees: ethUsdOrderFee
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
            isPremium: false
        });

        // TODO: Add price adapter
        SettlementConfiguration.Data memory linkUsdMarketOrderConfiguration = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_MARKET,
            isEnabled: true,
            fee: uint80(defaultSettlementFee),
            settlementStrategy: marketOrderSettlementStrategies.get(LINK_USD_MARKET_ID),
            data: abi.encode(linkUsdMarketOrderConfigurationData)
        });

        SettlementConfiguration.Data memory linkUsdLimitOrderConfiguration = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_CUSTOM,
            isEnabled: true,
            fee: uint80(defaultSettlementFee),
            settlementStrategy: limitOrderSettlementStrategies.get(LINK_USD_MARKET_ID),
            data: abi.encode(linkUsdMarketOrderConfigurationData)
        });

        SettlementConfiguration.Data[] memory linkUsdCustomTriggerStrategies = new SettlementConfiguration.Data[](1);
        linkUsdCustomTriggerStrategies[0] = linkUsdLimitOrderConfiguration;

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
                marketOrderConfiguration: linkUsdMarketOrderConfiguration,
                customTriggerStrategies: linkUsdCustomTriggerStrategies,
                orderFees: linkUsdOrderFee
            })
        });
    }

    function deployAndConfigureKeepers() internal {
        address limitOrderUpkeepImplementation = address(new LimitOrderUpkeep());
        address marketOrderUpkeepImplementation = address(new MarketOrderUpkeep());
        address ocoOrderUpkeepImplementation = address(new OcoOrderUpkeep());

        uint256[] memory limitOrderMarketIds = limitOrderSettlementStrategies.keys();
        uint256[] memory marketOrderMarketIds = marketOrderSettlementStrategies.keys();
        uint256[] memory ocoOrderMarketIds = ocoOrderSettlementStrategies.keys();

        for (uint256 i = 0; i < limitOrderMarketIds.length; i++) {
            uint256 marketId = limitOrderMarketIds[i];
            limitOrderUpkeeps[marketId].push(
                address(
                    new ERC1967Proxy(
                        limitOrderUpkeepImplementation,
                        abi.encodeWithSelector(
                            LimitOrderUpkeep.initialize.selector,
                            deployer,
                            limitOrderSettlementStrategies.get(marketId)
                        )
                    )
                )
            );
        }

        for (uint256 i = 0; i < marketOrderMarketIds.length; i++) {
            uint256 marketId = marketOrderMarketIds[i];
            marketOrderUpkeeps[marketId].push(
                address(
                    new ERC1967Proxy(
                        marketOrderUpkeepImplementation,
                        abi.encodeWithSelector(
                            MarketOrderUpkeep.initialize.selector,
                            deployer,
                            marketOrderSettlementStrategies.get(marketId)
                        )
                    )
                )
            );
        }

        for (uint256 i = 0; i < ocoOrderMarketIds.length; i++) {
            uint256 marketId = ocoOrderMarketIds[i];
            ocoOrderUpkeeps[marketId].push(
                address(
                    new ERC1967Proxy(
                        ocoOrderUpkeepImplementation,
                        abi.encodeWithSelector(
                            OcoOrderUpkeep.initialize.selector, deployer, ocoOrderSettlementStrategies.get(marketId)
                        )
                    )
                )
            );
        }

        LimitOrderSettlementStrategy limitOrderSettlementStrategy =
            LimitOrderSettlementStrategy(limitOrderSettlementStrategies.get(ETH_USD_MARKET_ID));
        MarketOrderSettlementStrategy marketOrderSettlementStrategy = MarketOrderSettlementStrategy(
            marketOrderSettlementStrategies.get(ETH_USD_MARKET_ID)
        );
        OcoOrderSettlementStrategy ocoOrderSettlementStrategy =
            OcoOrderSettlementStrategy(ocoOrderSettlementStrategies.get(ETH_USD_MARKET_ID));
    }

    function deploySettlementStrategies() internal {
        address limitOrderSettlementStrategyImplementation = address(new LimitOrderSettlementStrategy());
        address marketOrderSettlementStrategyImplementation = address(new MarketOrderSettlementStrategy());
        address ocoOrderSettlementStrategyImplementation = address(new OcoOrderSettlementStrategy());

        bytes memory ethUsdLimitOrderSettlementStrategyInitializeData = abi.encodeWithSelector(
            LimitOrderSettlementStrategy.initialize.selector,
            perpsEngine,
            ETH_USD_MARKET_ID,
            LIMIT_ORDER_SETTLEMENT_ID
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
            LIMIT_ORDER_SETTLEMENT_ID
        );
        bytes memory linkUsdMarketOrderSettlementStrategyInitializeData =
            abi.encodeWithSelector(MarketOrderSettlementStrategy.initialize.selector, perpsEngine, LINK_USD_MARKET_ID);
        bytes memory linkUsdOcoOrderSettlementStrategyInitializeData = abi.encodeWithSelector(
            OcoOrderSettlementStrategy.initialize.selector, perpsEngine, LINK_USD_MARKET_ID, OCO_ORDER_SETTLEMENT_ID
        );

        limitOrderSettlementStrategies.set(
            ETH_USD_MARKET_ID,
            address(
                new ERC1967Proxy(
                    limitOrderSettlementStrategyImplementation, ethUsdLimitOrderSettlementStrategyInitializeData
                )
            )
        );
        marketOrderSettlementStrategies.set(
            ETH_USD_MARKET_ID,
            address(
                new ERC1967Proxy(
                    marketOrderSettlementStrategyImplementation, ethUsdMarketOrderSettlementStrategyInitializeData
                )
            )
        );
        ocoOrderSettlementStrategies.set(
            ETH_USD_MARKET_ID,
            address(
                new ERC1967Proxy(
                    ocoOrderSettlementStrategyImplementation, ethUsdOcoOrderSettlementStrategyInitializeData
                )
            )
        );

        limitOrderSettlementStrategies.set(
            LINK_USD_MARKET_ID,
            address(
                new ERC1967Proxy(
                    limitOrderSettlementStrategyImplementation, linkUsdLimitOrderSettlementStrategyInitializeData
                )
            )
        );
        marketOrderSettlementStrategies.set(
            LINK_USD_MARKET_ID,
            address(
                new ERC1967Proxy(
                    marketOrderSettlementStrategyImplementation, linkUsdMarketOrderSettlementStrategyInitializeData
                )
            )
        );
        ocoOrderSettlementStrategies.set(
            LINK_USD_MARKET_ID,
            address(
                new ERC1967Proxy(
                    ocoOrderSettlementStrategyImplementation, linkUsdOcoOrderSettlementStrategyInitializeData
                )
            )
        );
    }
}
