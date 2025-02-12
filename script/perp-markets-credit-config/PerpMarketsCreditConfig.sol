// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { MockUsdToken } from "test/mocks/MockUsdToken.sol";
import { Constants } from "@zaros/utils/Constants.sol";

// Mock dependencies
import { MockEngine } from "test/mocks/MockEngine.sol";

// Forge dependencies
import { StdCheats, StdUtils } from "forge-std/Test.sol";

// Markets
import { BtcPerpMarketCreditConfig } from "script/perp-markets-credit-config/BtcPerpMarketCreditConfig.sol";
import { EthPerpMarketCreditConfig } from "script/perp-markets-credit-config/EthPerpMarketCreditConfig.sol";
import { ArbPerpMarketCreditConfig } from "script/perp-markets-credit-config/ArbPerpMarketCreditConfig.sol";
import { BnbPerpMarketCreditConfig } from "script/perp-markets-credit-config/BnbPerpMarketCreditConfig.sol";
import { DogePerpMarketCreditConfig } from "script/perp-markets-credit-config/DogePerpMarketCreditConfig.sol";
import { FtmPerpMarketCreditConfig } from "script/perp-markets-credit-config/FtmPerpMarketCreditConfig.sol";
import { LinkPerpMarketCreditConfig } from "script/perp-markets-credit-config/LinkPerpMarketCreditConfig.sol";
import { LtcPerpMarketCreditConfig } from "script/perp-markets-credit-config/LtcPerpMarketCreditConfig.sol";
import { MaticPerpMarketCreditConfig } from "script/perp-markets-credit-config/MaticPerpMarketCreditConfig.sol";
import { SolPerpMarketCreditConfig } from "script/perp-markets-credit-config/SolPerpMarketCreditConfig.sol";

/// @notice PerpMarketsCreditConfig contract
abstract contract PerpMarketsCreditConfig is
    StdCheats,
    StdUtils,
    BtcPerpMarketCreditConfig,
    EthPerpMarketCreditConfig,
    ArbPerpMarketCreditConfig,
    BnbPerpMarketCreditConfig,
    DogePerpMarketCreditConfig,
    FtmPerpMarketCreditConfig,
    LinkPerpMarketCreditConfig,
    LtcPerpMarketCreditConfig,
    MaticPerpMarketCreditConfig,
    SolPerpMarketCreditConfig
{
    /// @notice Perp Market Credit Config
    /// @param engine Engine address
    /// @param marketId Market id
    /// @param autoDeleverageStartThreshold Auto deleverage start threshold
    /// @param autoDeleverageEndThreshold Auto deleverage end threshold
    /// @param autoDeleverageExpoentZ Auto deleverage power scale
    struct PerpMarketCreditConfig {
        address engine;
        address usdToken;
        uint128 marketId;
        uint128 autoDeleverageStartThreshold;
        uint128 autoDeleverageEndThreshold;
        uint128 autoDeleverageExpoentZ;
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

    struct PerpMarketCreditByChain {
        address engine;
        address usdToken;
    }

    mapping(uint256 blockChainId => PerpMarketCreditByChain perpMarketData) perpMarketCreditByChain;

    /// @notice Setup perp markets credit config
    /// @param isTest When isTest is True a new mock engine will created for a each perp market using the initParams
    /// variable
    /// @param engine Only used when isTest is true
    /// @param usdToken Only used when isTest is true
    function setupPerpMarketsCreditConfig(bool isTest, address engine, address usdToken) internal {
        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].engine =
            BTC_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].usdToken =
            BTC_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].engine =
            BTC_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].usdToken =
            BTC_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketCreditByChain[Constants.FORGE_CHAIN_ID].engine = engine;
        perpMarketCreditByChain[Constants.FORGE_CHAIN_ID].usdToken = usdToken;

        perpMarketsCreditConfig[BTC_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: perpMarketCreditByChain[block.chainid].engine,
            usdToken: perpMarketCreditByChain[block.chainid].usdToken,
            marketId: BTC_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: BTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].engine =
            ETH_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].usdToken =
            ETH_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].engine =
            ETH_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].usdToken =
            ETH_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketsCreditConfig[ETH_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: perpMarketCreditByChain[block.chainid].engine,
            usdToken: perpMarketCreditByChain[block.chainid].usdToken,
            marketId: ETH_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: ETH_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].engine =
            SOL_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].usdToken =
            SOL_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].engine =
            SOL_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].usdToken =
            SOL_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketsCreditConfig[SOL_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: perpMarketCreditByChain[block.chainid].engine,
            usdToken: perpMarketCreditByChain[block.chainid].usdToken,
            marketId: SOL_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: SOL_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: SOL_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: SOL_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].engine =
            MATIC_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].usdToken =
            MATIC_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].engine =
            MATIC_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].usdToken =
            MATIC_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketsCreditConfig[MATIC_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: perpMarketCreditByChain[block.chainid].engine,
            usdToken: perpMarketCreditByChain[block.chainid].usdToken,
            marketId: MATIC_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: MATIC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: MATIC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: MATIC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].engine =
            LTC_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].usdToken =
            LTC_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].engine =
            LTC_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].usdToken =
            LTC_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketsCreditConfig[LTC_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: perpMarketCreditByChain[block.chainid].engine,
            usdToken: perpMarketCreditByChain[block.chainid].usdToken,
            marketId: LTC_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: LTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: LTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: LTC_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].engine =
            LINK_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].usdToken =
            LINK_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].engine =
            LINK_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].usdToken =
            LINK_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketsCreditConfig[LINK_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: perpMarketCreditByChain[block.chainid].engine,
            usdToken: perpMarketCreditByChain[block.chainid].usdToken,
            marketId: LINK_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: LINK_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: LINK_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: LINK_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].engine =
            FTM_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].usdToken =
            FTM_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].engine =
            FTM_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].usdToken =
            FTM_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketsCreditConfig[FTM_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: perpMarketCreditByChain[block.chainid].engine,
            usdToken: perpMarketCreditByChain[block.chainid].usdToken,
            marketId: FTM_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: FTM_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: FTM_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: FTM_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].engine =
            DOGE_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].usdToken =
            DOGE_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].engine =
            DOGE_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].usdToken =
            DOGE_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketsCreditConfig[DOGE_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: perpMarketCreditByChain[block.chainid].engine,
            usdToken: perpMarketCreditByChain[block.chainid].usdToken,
            marketId: DOGE_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: DOGE_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: DOGE_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: DOGE_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].engine =
            BNB_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].usdToken =
            BNB_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].engine =
            BNB_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].usdToken =
            BNB_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketsCreditConfig[BNB_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: perpMarketCreditByChain[block.chainid].engine,
            usdToken: perpMarketCreditByChain[block.chainid].usdToken,
            marketId: BNB_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: BNB_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: BNB_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: BNB_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
        });

        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].engine =
            ARB_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.ARB_SEPOLIA_CHAIN_ID].usdToken =
            ARB_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].engine =
            ARB_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE;
        perpMarketCreditByChain[Constants.MONAD_TESTNET_CHAIN_ID].usdToken =
            ARB_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN;

        perpMarketsCreditConfig[ARB_PERP_MARKET_CREDIT_CONFIG_ID] = PerpMarketCreditConfig({
            engine: perpMarketCreditByChain[block.chainid].engine,
            usdToken: perpMarketCreditByChain[block.chainid].usdToken,
            marketId: ARB_PERP_MARKET_CREDIT_CONFIG_ID,
            autoDeleverageStartThreshold: ARB_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD,
            autoDeleverageEndThreshold: ARB_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD,
            autoDeleverageExpoentZ: ARB_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE
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
                perpMarketsCreditConfig[i].autoDeleverageExpoentZ
            );

            params.marketMakingEngine.unpauseMarket(perpMarketsCreditConfig[i].marketId);

            params.marketMakingEngine.configureEngine(
                address(perpMarketsCreditConfig[i].engine), perpMarketsCreditConfig[i].usdToken, true
            );
        }
    }
}
