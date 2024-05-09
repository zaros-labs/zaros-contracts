// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";
import { MockPriceFeed } from "../../test/mocks/MockPriceFeed.sol";
import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";
import { IPerpsEngine } from "@zaros/perpetuals/interfaces/IPerpsEngine.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IGlobalConfigurationBranch } from "@zaros/perpetuals/interfaces/IGlobalConfigurationBranch.sol";

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
        address priceAdapter;
        bytes32 streamId;
        string streamIdString;
        OrderFees.Data orderFees;
        uint256 mockUsdPrice;
    }

    /// @notice Market configurations mapped by market id.
    mapping(uint256 marketId => MarketConfig marketConfig) internal marketsConfig;
    /// @notice Market order keepers contracts mapped by market id.
    mapping(uint256 marketId => address keeper) internal marketOrderKeepers;

    /// @notice General perps engine system configuration parameters.
    string internal constant DATA_STREAMS_FEED_PARAM_KEY = "feedIDs";
    string internal constant DATA_STREAMS_TIME_PARAM_KEY = "timestamp";
    uint80 internal constant DEFAULT_SETTLEMENT_FEE = 2e18;

    function setupMarketsConfig() internal {
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
            priceAdapter: BTC_USD_PRICE_FEED,
            streamId: BTC_USD_STREAM_ID,
            streamIdString: STRING_BTC_USD_STREAM_ID,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 }),
            mockUsdPrice: MOCK_BTC_USD_PRICE
        });
        marketsConfig[BTC_USD_MARKET_ID] = btcUsdConfig;

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
            priceAdapter: ETH_USD_PRICE_FEED,
            streamId: ETH_USD_STREAM_ID,
            streamIdString: STRING_ETH_USD_STREAM_ID,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 }),
            mockUsdPrice: MOCK_ETH_USD_PRICE
        });
        marketsConfig[ETH_USD_MARKET_ID] = ethUsdConfig;

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
            priceAdapter: LINK_USD_PRICE_FEED,
            streamId: LINK_USD_STREAM_ID,
            streamIdString: STRING_LINK_USD_STREAM_ID,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 }),
            mockUsdPrice: MOCK_LINK_USD_PRICE
        });
        marketsConfig[LINK_USD_MARKET_ID] = linkUsdConfig;

        MarketConfig memory arbUsdConfig = MarketConfig({
            marketId: ARB_USD_MARKET_ID,
            marketName: ARB_USD_MARKET_NAME,
            marketSymbol: ARB_USD_MARKET_SYMBOL,
            imr: ARB_USD_IMR,
            mmr: ARB_USD_MMR,
            marginRequirements: ARB_USD_MARGIN_REQUIREMENTS,
            maxOi: ARB_USD_MAX_OI,
            skewScale: ARB_USD_SKEW_SCALE,
            minTradeSize: ARB_USD_MIN_TRADE_SIZE,
            maxFundingVelocity: ARB_USD_MAX_FUNDING_VELOCITY,
            priceAdapter: ARB_USD_PRICE_FEED,
            streamId: ARB_USD_STREAM_ID,
            streamIdString: STRING_ARB_USD_STREAM_ID,
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 }),
            mockUsdPrice: MOCK_ARB_USD_PRICE
        });
        marketsConfig[ARB_USD_MARKET_ID] = arbUsdConfig;
    }

    function getFilteredMarketsConfig(uint256[2] memory marketsIdsRange)
        internal
        view
        returns (MarketConfig[] memory)
    {
        uint256 initialMarketId = marketsIdsRange[0];
        uint256 finalMarketId = marketsIdsRange[1];
        uint256 filteredMarketsLength = finalMarketId - initialMarketId + 1;

        MarketConfig[] memory filteredMarketsConfig = new MarketConfig[](filteredMarketsLength);

        uint256 nextMarketId = initialMarketId;
        for (uint256 i = 0; i < filteredMarketsLength; i++) {
            filteredMarketsConfig[i] = marketsConfig[nextMarketId];
            nextMarketId++;
        }

        return filteredMarketsConfig;
    }

    function createPerpMarkets(
        address deployer,
        address settlementFeeRecipient,
        IPerpsEngine perpsEngine,
        uint256 initialMarketId,
        uint256 finalMarketId,
        IVerifierProxy chainlinkVerifier,
        bool isTest
    )
        public
    {
        for (uint256 i = initialMarketId; i <= finalMarketId; i++) {
            address marketOrderKeeperImplementation = address(new MarketOrderKeeper());
            address marketOrderKeeper = deployMarketOrderKeeper(
                marketsConfig[i].marketId,
                deployer,
                perpsEngine,
                settlementFeeRecipient,
                marketOrderKeeperImplementation
            );

            SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
                .DataStreamsStrategy({ chainlinkVerifier: chainlinkVerifier, streamId: marketsConfig[i].streamId });

            SettlementConfiguration.Data memory marketOrderConfiguration = SettlementConfiguration.Data({
                strategy: SettlementConfiguration.Strategy.DATA_STREAMS_ONCHAIN,
                isEnabled: true,
                fee: DEFAULT_SETTLEMENT_FEE,
                keeper: marketOrderKeeper,
                data: abi.encode(marketOrderConfigurationData)
            });

            // TODO: update to API orderbook config
            SettlementConfiguration.Data[] memory customOrderStrategies;

            // update stored price adapter at tests
            address priceAdapter = isTest
                ? address(new MockPriceFeed(18, int256(marketsConfig[i].mockUsdPrice)))
                : marketsConfig[i].priceAdapter;

            marketsConfig[i].priceAdapter = priceAdapter;

            perpsEngine.createPerpMarket(
                IGlobalConfigurationBranch.CreatePerpMarketParams({
                    marketId: marketsConfig[i].marketId,
                    name: marketsConfig[i].marketName,
                    symbol: marketsConfig[i].marketSymbol,
                    priceAdapter: priceAdapter,
                    initialMarginRateX18: marketsConfig[i].imr,
                    maintenanceMarginRateX18: marketsConfig[i].mmr,
                    maxOpenInterest: marketsConfig[i].maxOi,
                    maxFundingVelocity: marketsConfig[i].maxFundingVelocity,
                    skewScale: marketsConfig[i].skewScale,
                    minTradeSizeX18: marketsConfig[i].minTradeSize,
                    marketOrderConfiguration: marketOrderConfiguration,
                    customOrderStrategies: customOrderStrategies,
                    orderFees: marketsConfig[i].orderFees
                })
            );
        }
    }

    function deployMarketOrderKeeper(
        uint128 marketId,
        address deployer,
        IPerpsEngine perpsEngine,
        address settlementFeeRecipient,
        address marketOrderKeeperImplementation
    )
        internal
        returns (address marketOrderKeeper)
    {
        marketOrderKeeper = address(
            new ERC1967Proxy(
                marketOrderKeeperImplementation,
                abi.encodeWithSelector(
                    MarketOrderKeeper.initialize.selector,
                    deployer,
                    perpsEngine,
                    settlementFeeRecipient,
                    marketId,
                    marketsConfig[marketId].streamIdString
                )
            )
        );

        marketOrderKeepers[marketId] = marketOrderKeeper;
    }
}
