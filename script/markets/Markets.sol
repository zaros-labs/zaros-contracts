// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { MockPriceFeed } from "../../test/mocks/MockPriceFeed.sol";
import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IGlobalConfigurationModule } from "@zaros/markets/perps/interfaces/IGlobalConfigurationModule.sol";

// PRB Math dependencies
import { uMAX_UD60x18 as LIB_uMAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { uMAX_SD59x18 as LIB_uMAX_SD59x18, uMIN_SD59x18 as LIB_uMIN_SD59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Markets
import { ArbUsd } from "./ArbUsd.sol";
import { BtcUsd } from "./BtcUsd.sol";
import { EthUsd } from "./EthUsd.sol";
import { LinkUsd } from "./LinkUsd.sol";

contract Markets is ArbUsd, BtcUsd, EthUsd, LinkUsd {
    struct MarketConfig {
        uint128 marketId;
        string marketName;
        string marketSymbol;
        uint128 imr;
        uint128 mmr;
        uint128 marginRequirements;
        uint128 maxOi;
        uint256 skewScale;
        uint256 minTradeSize;
        uint128 maxFundingVelocity;
        uint248 settlementDelay;
        bool isPremiumFeed;
        address priceAdapter;
        string streamId;
        OrderFees.Data orderFees;
        uint256 mockUsdPrice;
    }

    mapping(uint256 marketId => address keeper) internal marketOrderKeepers;

    /// @notice General perps engine system configuration parameters.
    string internal constant DATA_STREAMS_FEED_PARAM_KEY = "feedIDs";
    string internal constant DATA_STREAMS_TIME_PARAM_KEY = "timestamp";
    uint80 internal constant DATA_STREAMS_SETTLEMENT_FEE = 1e18;
    uint80 internal constant DEFAULT_SETTLEMENT_FEE = 2e18;

    function getMarketsConfig(uint256[] memory filteredIndexMarkets) internal pure returns (MarketConfig[] memory) {
        MarketConfig[] memory marketsConfig = new MarketConfig[](3);

        MarketConfig memory ethUsdConfig = MarketConfig({
            marketId: ETH_USD_MARKET_ID,
            marketName: ETH_USD_MARKET_NAME,
            marketSymbol: ETH_USD_MARKET_SYMBOL,
            imr: ETH_USD_IMR,
            mmr: ETH_USD_MMR,
            marginRequirements: ETH_USD_MARGIN_REQUIREMENTS,
            maxOi: ETH_USD_MAX_OI,
            skewScale: ETH_USD_SKEW_SCALE,
            minTradeSize: ETH_USD_MIN_TRADE_SIZE,
            maxFundingVelocity: ETH_USD_MAX_FUNDING_VELOCITY,
            settlementDelay: ETH_USD_SETTLEMENT_DELAY,
            isPremiumFeed: ETH_USD_IS_PREMIUM_FEED,
            priceAdapter: ETH_USD_PRICE_FEED,
            streamId: ETH_USD_STREAM_ID,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 }),
            mockUsdPrice: MOCK_ETH_USD_PRICE
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
            minTradeSize: LINK_USD_MIN_TRADE_SIZE,
            maxFundingVelocity: LINK_USD_MAX_FUNDING_VELOCITY,
            settlementDelay: LINK_USD_SETTLEMENT_DELAY,
            isPremiumFeed: LINK_USD_IS_PREMIUM_FEED,
            priceAdapter: LINK_USD_PRICE_FEED,
            streamId: LINK_USD_STREAM_ID,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 }),
            mockUsdPrice: MOCK_LINK_USD_PRICE
        });
        marketsConfig[1] = linkUsdConfig;

        MarketConfig memory btcUsdConfig = MarketConfig({
            marketId: BTC_USD_MARKET_ID,
            marketName: BTC_USD_MARKET_NAME,
            marketSymbol: BTC_USD_MARKET_SYMBOL,
            imr: BTC_USD_IMR,
            mmr: BTC_USD_MMR,
            marginRequirements: BTC_USD_MARGIN_REQUIREMENTS,
            maxOi: BTC_USD_MAX_OI,
            skewScale: BTC_USD_SKEW_SCALE,
            minTradeSize: BTC_USD_MIN_TRADE_SIZE,
            maxFundingVelocity: BTC_USD_MAX_FUNDING_VELOCITY,
            settlementDelay: BTC_USD_SETTLEMENT_DELAY,
            isPremiumFeed: BTC_USD_IS_PREMIUM_FEED,
            priceAdapter: BTC_USD_PRICE_FEED,
            streamId: BTC_USD_STREAM_ID,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 }),
            mockUsdPrice: MOCK_BTC_USD_PRICE
        });
        marketsConfig[2] = btcUsdConfig;

        uint256 initialMarketIndex = filteredIndexMarkets[0];
        uint256 finalMarketIndex = filteredIndexMarkets[1];

        uint256 lengthFilteredMarkets;
        if (initialMarketIndex == finalMarketIndex) {
            lengthFilteredMarkets = 1;
        } else {
            lengthFilteredMarkets = (finalMarketIndex - initialMarketIndex) + 1;
        }

        MarketConfig[] memory filteredMarketsConfig = new MarketConfig[](lengthFilteredMarkets);

        uint256 filteredIndex = 0;
        for (uint256 index = initialMarketIndex; index <= finalMarketIndex; index++) {
            filteredMarketsConfig[filteredIndex] = marketsConfig[index];
            filteredIndex++;
        }

        return filteredMarketsConfig;
    }

    function createPerpMarkets(
        address deployer,
        address settlementFeeReceiver,
        IPerpsEngine perpsEngine,
        MarketConfig[] memory marketsConfig,
        IVerifierProxy chainlinkVerifier,
        bool isTest
    )
        public
    {
        for (uint256 i = 0; i < marketsConfig.length; i++) {
            address marketOrderKeeper = deployMarketOrderKeeper(
                marketsConfig[i].marketId,
                deployer,
                perpsEngine,
                settlementFeeReceiver
            );

            SettlementConfiguration.DataStreamsMarketStrategy memory marketOrderConfigurationData =
            SettlementConfiguration.DataStreamsMarketStrategy({
                chainlinkVerifier: chainlinkVerifier,
                streamId: marketsConfig[i].streamId,
                feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
                queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
                settlementDelay: marketsConfig[i].settlementDelay,
                isPremium: marketsConfig[i].isPremiumFeed
            });

            SettlementConfiguration.Data memory marketOrderConfiguration = SettlementConfiguration.Data({
                strategy: SettlementConfiguration.Strategy.DATA_STREAMS_MARKET,
                isEnabled: true,
                fee: DEFAULT_SETTLEMENT_FEE,
                keeper: marketOrderKeeper,
                data: abi.encode(marketOrderConfigurationData)
            });

            // TODO: update to API orderbook config
            SettlementConfiguration.Data[] memory customOrderStrategies;

            perpsEngine.createPerpMarket(
                IGlobalConfigurationModule.CreatePerpMarketParams({
                    marketId: marketsConfig[i].marketId,
                    name: marketsConfig[i].marketName,
                    symbol: marketsConfig[i].marketSymbol,
                    priceAdapter: isTest ? address(new MockPriceFeed(18, int256(marketsConfig[i].mockUsdPrice))) : marketsConfig[i].priceAdapter,
                    initialMarginRateX18: marketsConfig[i].imr,
                    maintenanceMarginRateX18: marketsConfig[i].mmr,
                    maxOpenInterest: marketsConfig[i].maxOi,
                    maxFundingVelocity: marketsConfig[i].maxFundingVelocity,
                    skewScale: marketsConfig[i].skewScale,
                    minTradeSizeX18: marketsConfig[i].minTradeSize,
                    marketOrderConfiguration: marketOrderConfiguration,
                    customTriggerStrategies: customOrderStrategies,
                    orderFees: marketsConfig[i].orderFees
                })
            );
        }
    }

    function deployMarketOrderKeeper(
        uint128 marketId,
        address deployer,
        IPerpsEngine perpsEngine,
        address settlementFeeReceiver
    )
        internal
        returns (address marketOrderKeeper)
    {
        address marketOrderKeeperImplementation = address(new MarketOrderKeeper());

        marketOrderKeeper = address(
            new ERC1967Proxy(
                marketOrderKeeperImplementation,
                abi.encodeWithSelector(
                    MarketOrderKeeper.initialize.selector, deployer, perpsEngine, settlementFeeReceiver, marketId
                )
            )
        );

        marketOrderKeepers[marketId] = marketOrderKeeper;
    }
}
