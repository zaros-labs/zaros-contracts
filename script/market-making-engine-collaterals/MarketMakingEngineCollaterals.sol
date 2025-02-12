// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Margin Collaterals
import { Usdc } from "script/market-making-engine-collaterals/Usdc.sol";
import { WBtc } from "script/market-making-engine-collaterals/WBtc.sol";
import { WEth } from "script/market-making-engine-collaterals/WEth.sol";
import { WstEth } from "script/market-making-engine-collaterals/WstEth.sol";

// Zaros dependencies
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { PriceAdapter } from "@zaros/utils/PriceAdapter.sol";
import { Constants } from "@zaros/utils/Constants.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

abstract contract MarketMakingEngineCollaterals is Usdc, WBtc, WEth, WstEth {
    struct MarketMakingEngineCollateral {
        address collateral;
        address priceAdapter;
        uint256 creditRatio;
        bool isEnabled;
        uint8 decimals;
    }

    mapping(uint256 marketMakingEngineCollateralId => MarketMakingEngineCollateral marketMakingEngineCollateral)
        internal marketMakingEngineCollaterals;

    struct CollateralDataByChain {
        address collateral;
        address priceAdapter;
    }

    mapping(uint256 chainId => CollateralDataByChain collateral) collateralByChain;

    function setupMarketMakingEngineCollaterals() internal {
        collateralByChain[Constants.ARB_SEPOLIA_CHAIN_ID].collateral = USDC_ARB_SEPOLIA_MARKET_MAKING_ENGINE_ADDRESS;
        collateralByChain[Constants.ARB_SEPOLIA_CHAIN_ID].priceAdapter =
            USDC_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER;

        collateralByChain[Constants.MONAD_TESTNET_CHAIN_ID].collateral =
            USDC_MONAD_TESTNET_MARKET_MAKING_ENGINE_ADDRESS;
        collateralByChain[Constants.MONAD_TESTNET_CHAIN_ID].priceAdapter =
            USDC_MONAD_TESTNET_MARKET_MAKING_ENGINE_PRICE_ADAPTER;

        collateralByChain[Constants.FORGE_CHAIN_ID].collateral = address(0x1);
        collateralByChain[Constants.FORGE_CHAIN_ID].priceAdapter = address(0x1);

        MarketMakingEngineCollateral memory usdcConfig = MarketMakingEngineCollateral({
            collateral: collateralByChain[block.chainid].collateral,
            priceAdapter: collateralByChain[block.chainid].priceAdapter,
            creditRatio: USDC_MARKET_MAKING_ENGINE_CREDIT_RATIO,
            isEnabled: USDC_MARKET_MAKING_ENGINE_IS_ENABLED,
            decimals: USDC_MARKET_MAKING_ENGINE_DECIMALS
        });
        marketMakingEngineCollaterals[USDC_MARKET_MAKING_ENGINE_COLLATERAL_ID] = usdcConfig;

        collateralByChain[Constants.ARB_SEPOLIA_CHAIN_ID].collateral = WBTC_ARB_SEPOLIA_MARKET_MAKING_ENGINE_ADDRESS;
        collateralByChain[Constants.ARB_SEPOLIA_CHAIN_ID].priceAdapter =
            WBTC_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER;

        collateralByChain[Constants.MONAD_TESTNET_CHAIN_ID].collateral =
            WBTC_MONAD_TESTNET_MARKET_MAKING_ENGINE_ADDRESS;
        collateralByChain[Constants.MONAD_TESTNET_CHAIN_ID].priceAdapter =
            WBTC_MONAD_TESTNET_MARKET_MAKING_ENGINE_PRICE_ADAPTER;

        collateralByChain[Constants.FORGE_CHAIN_ID].collateral = address(0x2);
        collateralByChain[Constants.FORGE_CHAIN_ID].priceAdapter = address(0x2);

        MarketMakingEngineCollateral memory wBtcConfig = MarketMakingEngineCollateral({
            collateral: collateralByChain[block.chainid].collateral,
            priceAdapter: collateralByChain[block.chainid].priceAdapter,
            creditRatio: WBTC_MARKET_MAKING_ENGINE_CREDIT_RATIO,
            isEnabled: WBTC_MARKET_MAKING_ENGINE_IS_ENABLED,
            decimals: WBTC_MARKET_MAKING_ENGINE_DECIMALS
        });
        marketMakingEngineCollaterals[WBTC_MARKET_MAKING_ENGINE_COLLATERAL_ID] = wBtcConfig;

        collateralByChain[Constants.ARB_SEPOLIA_CHAIN_ID].collateral = WETH_ARB_SEPOLIA_MARKET_MAKING_ENGINE_ADDRESS;
        collateralByChain[Constants.ARB_SEPOLIA_CHAIN_ID].priceAdapter =
            WETH_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER;

        collateralByChain[Constants.MONAD_TESTNET_CHAIN_ID].collateral =
            WETH_MONAD_TESTNET_MARKET_MAKING_ENGINE_ADDRESS;
        collateralByChain[Constants.MONAD_TESTNET_CHAIN_ID].priceAdapter =
            WETH_MONAD_TESTNET_MARKET_MAKING_ENGINE_PRICE_ADAPTER;

        collateralByChain[Constants.FORGE_CHAIN_ID].collateral = address(0x3);
        collateralByChain[Constants.FORGE_CHAIN_ID].priceAdapter = address(0x3);

        MarketMakingEngineCollateral memory wEthConfig = MarketMakingEngineCollateral({
            collateral: collateralByChain[block.chainid].collateral,
            priceAdapter: collateralByChain[block.chainid].priceAdapter,
            creditRatio: WETH_MARKET_MAKING_ENGINE_CREDIT_RATIO,
            isEnabled: WETH_MARKET_MAKING_ENGINE_IS_ENABLED,
            decimals: WETH_MARKET_MAKING_ENGINE_DECIMALS
        });
        marketMakingEngineCollaterals[WETH_MARKET_MAKING_ENGINE_COLLATERAL_ID] = wEthConfig;

        collateralByChain[Constants.ARB_SEPOLIA_CHAIN_ID].collateral = WSTETH_ARB_SEPOLIA_MARKET_MAKING_ENGINE_ADDRESS;
        collateralByChain[Constants.ARB_SEPOLIA_CHAIN_ID].priceAdapter =
            WSTETH_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER;

        collateralByChain[Constants.MONAD_TESTNET_CHAIN_ID].collateral =
            WSTETH_MONAD_TESTNET_MARKET_MAKING_ENGINE_ADDRESS;
        collateralByChain[Constants.MONAD_TESTNET_CHAIN_ID].priceAdapter =
            WSTETH_MONAD_TESTNET_MARKET_MAKING_ENGINE_PRICE_ADAPTER;

        collateralByChain[Constants.FORGE_CHAIN_ID].collateral = address(0x4);
        collateralByChain[Constants.FORGE_CHAIN_ID].priceAdapter = address(0x4);

        MarketMakingEngineCollateral memory wstEthConfig = MarketMakingEngineCollateral({
            collateral: collateralByChain[block.chainid].collateral,
            priceAdapter: collateralByChain[block.chainid].priceAdapter,
            creditRatio: WSTETH_MARKET_MAKING_ENGINE_CREDIT_RATIO,
            isEnabled: WSTETH_MARKET_MAKING_ENGINE_IS_ENABLED,
            decimals: WSTETH_MARKET_MAKING_ENGINE_DECIMALS
        });
        marketMakingEngineCollaterals[WSTETH_MARKET_MAKING_ENGINE_COLLATERAL_ID] = wstEthConfig;
    }

    function getFilteredMarketMakingEngineCollateralsConfig(uint256[2] memory marketMakingEngineCollateralIdsRange)
        internal
        view
        returns (MarketMakingEngineCollateral[] memory)
    {
        uint256 initialMarketMakingEngineCollateralId = marketMakingEngineCollateralIdsRange[0];
        uint256 finalMarketMakingEngineCollateralId = marketMakingEngineCollateralIdsRange[1];
        uint256 filteredCollateralsLength =
            finalMarketMakingEngineCollateralId - initialMarketMakingEngineCollateralId + 1;

        MarketMakingEngineCollateral[] memory filteredMarginCollateralsConfig =
            new MarketMakingEngineCollateral[](filteredCollateralsLength);

        uint256 nextMarketMakingEngineCollateralId = initialMarketMakingEngineCollateralId;
        for (uint256 i; i < filteredCollateralsLength; i++) {
            filteredMarginCollateralsConfig[i] = marketMakingEngineCollaterals[nextMarketMakingEngineCollateralId];
            nextMarketMakingEngineCollateralId++;
        }

        return filteredMarginCollateralsConfig;
    }

    function configureMarketMakingEngineCollaterals(
        IMarketMakingEngine marketMakingEngine,
        uint256[2] memory marketMakingEngineCollateralIdsRange
    )
        internal
    {
        setupMarketMakingEngineCollaterals();

        MarketMakingEngineCollateral[] memory filteredMarketMakingCollateralsConfig =
            getFilteredMarketMakingEngineCollateralsConfig(marketMakingEngineCollateralIdsRange);

        for (uint256 i; i < filteredMarketMakingCollateralsConfig.length; i++) {
            marketMakingEngine.configureCollateral(
                filteredMarketMakingCollateralsConfig[i].collateral,
                filteredMarketMakingCollateralsConfig[i].priceAdapter,
                filteredMarketMakingCollateralsConfig[i].creditRatio,
                filteredMarketMakingCollateralsConfig[i].isEnabled,
                filteredMarketMakingCollateralsConfig[i].decimals
            );

            console.log("Success! Configured collateral:");
            console.log("\n");
            console.log("Collateral: ", filteredMarketMakingCollateralsConfig[i].collateral);
            console.log("Price Adapter: ", filteredMarketMakingCollateralsConfig[i].priceAdapter);
            console.log("Credit ratio: ", filteredMarketMakingCollateralsConfig[i].creditRatio);
            console.log("Is enabled: ", filteredMarketMakingCollateralsConfig[i].isEnabled);
            console.log("Decimals: ", filteredMarketMakingCollateralsConfig[i].decimals);
        }
    }
}
