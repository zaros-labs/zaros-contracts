// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";
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
// TODO: update owner and forwarder on keeper initialization
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
    address internal settlementFeeReceiver;

    function run(uint256 initialMarketIndex, uint256 finalMarketIndex) public broadcaster {
        perpsEngine = IPerpsEngine(payable(address(vm.envAddress("PERPS_ENGINE"))));
        chainlinkVerifier = IVerifierProxy(vm.envAddress("CHAINLINK_VERIFIER"));
        settlementFeeReceiver = vm.envAddress("SETTLEMENT_FEE_RECEIVER");

        address[] memory priceAdapters = new address[](2);
        priceAdapters[0] = vm.envAddress("ETH_USD_PRICE_FEED");
        priceAdapters[1] = vm.envAddress("LINK_USD_PRICE_FEED");

        string[] memory streamIds = new string[](2);
        streamIds[0] = vm.envString("ETH_USD_STREAM_ID");
        streamIds[1] = vm.envString("LINK_USD_STREAM_ID");

        uint256[] memory filteredIndexMarkets = new uint256[](2);
        filteredIndexMarkets[0] = initialMarketIndex;
        filteredIndexMarkets[1] = finalMarketIndex;

        (MarketConfig[] memory marketsConfig) = getMarketsConfig(priceAdapters, streamIds, filteredIndexMarkets);

        for (uint256 i = 0; i < marketsConfig.length; i++) {
            SettlementConfiguration.DataStreamsMarketStrategy memory marketOrderConfigurationData =
            SettlementConfiguration.DataStreamsMarketStrategy({
                chainlinkVerifier: chainlinkVerifier,
                streamId: marketsConfig[i].streamId,
                feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
                queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
                settlementDelay: marketsConfig[i].settlementDelay,
                isPremium: marketsConfig[i].isPremiumFeed
            });

            address marketOrderKeeper = deployMarketOrderKeeper(marketsConfig[i].marketId);

            SettlementConfiguration.Data memory marketOrderConfiguration = SettlementConfiguration.Data({
                strategy: SettlementConfiguration.Strategy.DATA_STREAMS_MARKET,
                isEnabled: true,
                fee: DEFAULT_SETTLEMENT_FEE,
                keeper: marketOrderKeeper,
                data: abi.encode(marketOrderConfigurationData)
            });

            // TODO: configure custom orders and set the API's keeper
            SettlementConfiguration.Data[] memory customOrdersConfigurations;

            perpsEngine.createPerpMarket({
                params: IGlobalConfigurationModule.CreatePerpMarketParams({
                    marketId: marketsConfig[i].marketId,
                    name: marketsConfig[i].marketName,
                    symbol: marketsConfig[i].marketSymbol,
                    priceAdapter: marketsConfig[i].priceAdapter,
                    initialMarginRateX18: marketsConfig[i].imr,
                    maintenanceMarginRateX18: marketsConfig[i].mmr,
                    maxOpenInterest: marketsConfig[i].maxOi,
                    skewScale: marketsConfig[i].skewScale,
                    minTradeSizeX18: marketsConfig[i].minTradeSize,
                    maxFundingVelocity: marketsConfig[i].maxFundingVelocity,
                    marketOrderConfiguration: marketOrderConfiguration,
                    customTriggerStrategies: customOrdersConfigurations,
                    orderFees: marketsConfig[i].orderFees
                })
            });
        }
    }

    function deployMarketOrderKeeper(uint128 marketId) internal returns (address marketOrderKeeper) {
        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());

        console.log("MarketOrderKeeper Implementation: ", marketOrderKeeperImplementation);

        marketOrderKeeper = address(
            new ERC1967Proxy(
                marketOrderKeeperImplementation,
                abi.encodeWithSelector(
                    MarketOrderKeeper.initialize.selector, deployer, perpsEngine, settlementFeeReceiver, marketId
                )
            )
        );
    }
}
