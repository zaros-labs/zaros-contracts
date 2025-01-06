// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";

// Mock dependencies
import { MockEngine } from "test/mocks/MockEngine.sol";

// Forge dependencies
import { StdCheats, StdUtils } from "forge-std/Test.sol";

// Markets
import { BtcPerpMarketCreditConfig } from "script/perp-markets-credit-config/BtcPerpMarketCreditConfig.sol";
import { EthPerpMarketCreditConfig } from "script/perp-markets-credit-config/EthPerpMarketCreditConfig.sol";

/// @notice PerpMarketsCreditConfig contract
abstract contract PerpMarketsCreditConfig is
    StdCheats,
    StdUtils,
    BtcPerpMarketCreditConfig,
    EthPerpMarketCreditConfig
{

    /// @notice Perp Market Credit Config
    /// @param engine Engine address
    /// @param marketId Market id
    /// @param autoDeleverageStartThreshold Auto deleverage start threshold
    /// @param autoDeleverageEndThreshold Auto deleverage end threshold
    /// @param autoDeleverageExpoentZ Auto deleverage power scale
    struct PerpMarketCreditConfig {
        address engine;
        uint128 marketId;
        uint128 autoDeleverageStartThreshold;
        uint128 autoDeleverageEndThreshold;
        uint128 autoDeleverageExpoentZ;
    }

    /// @notice Configure market params
    /// @param perpsEngine Perps engine
    /// @param marketMakingEngine Market making engine
    /// @param initialMarketId Initial market id
    /// @param finalMarketId Final market id
    struct ConfigureMarketParams {
        address perpsEngine;
        IMarketMakingEngine marketMakingEngine;
        uint256 initialMarketId;
        uint256 finalMarketId;
    }

    /// @notice Perp market credit configurations mapped by market id.
    mapping(uint256 marketId => PerpMarketCreditConfig marketConfig) internal perpMarketsCreditConfig;

    /// @notice Setup perp markets credit config
    /// @param isTest When isTest is True a new mock engine will created for a each perp market using the initParams variable
    /// @param initParams Only used when isTest is true
    function setupPerpMarketsCreditConfig(bool isTest, RootProxy.InitParams memory initParams) internal {
        perpMarketsCreditConfig[BTC_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: isTest ? address(new MockEngine(initParams)) : BTC_PERP_MARKET_CREDIT_CONFIG_ENGINE,
            marketId: BTC_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketsCreditConfig[ETH_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: isTest ? address(new MockEngine(initParams)) : ETH_PERP_MARKET_CREDIT_CONFIG_ENGINE,
            marketId: ETH_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });
    }

    /// @notice Get filtered perp markets credit config
    /// @param marketsIdsRange Markets ids range
    function getFilteredPerpMarketsCreditConfig(uint256[2] memory marketsIdsRange)
        internal
        view
        returns (PerpMarketCreditConfig[] memory)
    {
        uint256 initialMarketId = marketsIdsRange[0];
        uint256 finalMarketId = marketsIdsRange[1];
        uint256 filteredMarketsLength = finalMarketId - initialMarketId + 1;

        PerpMarketCreditConfig[] memory filteredPerpMarketsCreditConfig =
            new PerpMarketCreditConfig[](filteredMarketsLength);

        uint256 nextMarketId = initialMarketId;
        for (uint256 i; i < filteredMarketsLength; i++) {
            filteredPerpMarketsCreditConfig[i] = perpMarketsCreditConfig[nextMarketId];
            nextMarketId++;
        }

        return filteredPerpMarketsCreditConfig;
    }

    /// @notice Configure markets
    /// @param params Configure market params
    function configureMarkets(ConfigureMarketParams memory params) public {
        for (uint256 i = params.initialMarketId; i <= params.finalMarketId; i++) {
            params.marketMakingEngine.configureMarket(
                params.perpsEngine,
                perpMarketsCreditConfig[i].marketId,
                perpMarketsCreditConfig[i].autoDeleverageStartThreshold,
                perpMarketsCreditConfig[i].autoDeleverageEndThreshold,
                perpMarketsCreditConfig[i].autoDeleverageExpoentZ
            );

            params.marketMakingEngine.unpauseMarket(perpMarketsCreditConfig[i].marketId);
        }
    }
}
