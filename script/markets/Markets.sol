// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";

// PRB Math dependencies
import { uMAX_UD60x18 as LIB_uMAX_UD60x18 } from "@prb-math/UD60x18.sol";
import { uMAX_SD59x18 as LIB_uMAX_SD59x18, uMIN_SD59x18 as LIB_uMIN_SD59x18 } from "@prb-math/SD59x18.sol";

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
    }

    function getMarketsConfig(address[] memory addressPriceFeeds, string[] memory streamIds, uint256[] memory filteredIndexMarkets) internal pure returns(MarketConfig[] memory){

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
            minTradeSize: ETH_USD_MIN_TRADE_SIZE,
            maxFundingVelocity: ETH_USD_MAX_FUNDING_VELOCITY,
            settlementDelay: ETH_USD_SETTLEMENT_DELAY,
            isPremiumFeed: ETH_USD_IS_PREMIUM_FEED,
            priceAdapter: addressPriceFeeds[0],
            streamId: streamIds[0],
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
            minTradeSize: LINK_USD_MIN_TRADE_SIZE,
            maxFundingVelocity: LINK_USD_MAX_FUNDING_VELOCITY,
            settlementDelay: LINK_USD_SETTLEMENT_DELAY,
            isPremiumFeed: LINK_USD_IS_PREMIUM_FEED,
            priceAdapter: addressPriceFeeds[1],
            streamId: streamIds[1],
            orderFees: OrderFees.Data({ makerFee: 0.0004e18, takerFee: 0.0008e18 })
        });
        marketsConfig[1] = linkUsdConfig;

        uint256 initialMarketIndex = filteredIndexMarkets[0];
        uint256 finalMarketIndex = filteredIndexMarkets[1];

        uint256 lengthFilteredMarkets;
        if(initialMarketIndex == finalMarketIndex) {
            lengthFilteredMarkets = 1;
        } else {
            lengthFilteredMarkets = (finalMarketIndex - initialMarketIndex) + 1;
        }

        MarketConfig[] memory filteredMarketsConfig = new MarketConfig[](lengthFilteredMarkets);

        uint256 filteredIndex = 0;
        for(uint256 index = initialMarketIndex; index <= finalMarketIndex; index++) {
            filteredMarketsConfig[filteredIndex] = marketsConfig[index];
            filteredIndex++;
        }

        return filteredMarketsConfig;
    }
}
