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
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

// TODO: update limit order strategies
// TODO: update owner and forwarder on keeper initialization
contract CreatePerpMarket is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    IVerifierProxy internal chainlinkVerifier;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IPerpsEngine internal perpsEngine;
    address internal settlementFeeReceiver;

    function run(uint256 INITIAL_MARKET_INDEX, uint256 FINAL_MARKET_INDEX) public broadcaster {
        perpsEngine = IPerpsEngine(payable(address(vm.envAddress("PERPS_ENGINE"))));
        chainlinkVerifier = IVerifierProxy(vm.envAddress("CHAINLINK_VERIFIER"));
        settlementFeeReceiver = vm.envAddress("SETTLEMENT_FEE_RECEIVER");

        uint256[] memory filteredIndexMarkets = new uint256[](2);
        filteredIndexMarkets[0] = INITIAL_MARKET_INDEX;
        filteredIndexMarkets[1] = FINAL_MARKET_INDEX;

        (MarketConfig[] memory marketsConfig) = getMarketsConfig(filteredIndexMarkets);

        for (uint256 i = 0; i < marketsConfig.length; i++) {
            SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
                .DataStreamsStrategy({
                chainlinkVerifier: chainlinkVerifier,
                streamId: marketsConfig[i].streamId,
                feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
                queryLabel: DATA_STREAMS_TIME_PARAM_KEY
            });

            address marketOrderKeeperImplementation = address(new MarketOrderKeeper());
            console.log("MarketOrderKeeper Implementation: ", marketOrderKeeperImplementation);
            address marketOrderKeeper =
                deployMarketOrderKeeper(marketsConfig[i].marketId, marketOrderKeeperImplementation);

            SettlementConfiguration.Data memory marketOrderConfiguration = SettlementConfiguration.Data({
                strategy: SettlementConfiguration.Strategy.DATA_STREAMS_ONCHAIN,
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
                    customOrderStrategies: customOrdersConfigurations,
                    orderFees: marketsConfig[i].orderFees
                })
            });
        }
    }

    function deployMarketOrderKeeper(
        uint128 marketId,
        address marketOrderKeeperImplementation
    )
        internal
        returns (address marketOrderKeeper)
    {
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
