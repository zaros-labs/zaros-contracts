// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";

// Mock dependencies
import { MockEngine } from "test/mocks/MockEngine.sol";

// Forge dependencies
import { StdCheats, StdUtils } from "forge-std/Test.sol";

// Markets
import { BtcPerpMarketCreditConfig } from "script/perp-markets-credit-config/BtcPerpMarketCreditConfig.sol";
import { EthPerpMarketCreditConfig } from "script/perp-markets-credit-config/EthPerpMarketCreditConfig.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

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
    /// @param autoDeleveragePowerScale Auto deleverage power scale
    struct PerpMarketCreditConfig {
        address engine;
        uint128 marketId;
        uint128 autoDeleverageStartThreshold;
        uint128 autoDeleverageEndThreshold;
        uint128 autoDeleveragePowerScale;
    }

    /// @notice Configure market params
    /// @param marketMakingEngine Market making engine
    /// @param initialMarketId Initial market id
    /// @param finalMarketId Final market id
    struct ConfigureMarketParams {
        IMarketMakingEngine marketMakingEngine;
        uint256 initialMarketId;
        uint256 finalMarketId;
    }

    /// @notice Perp market credit configurations mapped by market id.
    mapping(uint256 marketId => PerpMarketCreditConfig marketConfig) internal perpMarketsCreditConfig;

    /// @notice Setup perp markets credit config
    function setupPerpMarketsCreditConfig(bool isTest) internal {
        perpMarketsCreditConfig[BTC_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: !isTest ? BTC_PERP_MARKET_CREDIT_CONFIG_ENGINE : address(new MockEngine()),
            marketId: BTC_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleveragePowerScale: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketsCreditConfig[ETH_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: !isTest ? ETH_PERP_MARKET_CREDIT_CONFIG_ENGINE : address(new MockEngine()),
            marketId: ETH_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleveragePowerScale: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
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
                perpMarketsCreditConfig[i].engine,
                perpMarketsCreditConfig[i].marketId,
                perpMarketsCreditConfig[i].autoDeleverageStartThreshold,
                perpMarketsCreditConfig[i].autoDeleverageEndThreshold,
                perpMarketsCreditConfig[i].autoDeleveragePowerScale
            );

            params.marketMakingEngine.unpauseMarket(perpMarketsCreditConfig[i].marketId);
        }
    }
}
