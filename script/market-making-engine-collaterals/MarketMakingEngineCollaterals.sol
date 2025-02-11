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

    function setupMarketMakingEngineCollaterals() internal {
        MarketMakingEngineCollateral memory usdcConfig = MarketMakingEngineCollateral({
            collateral: USDC_MARKET_MAKING_ENGINE_ADDRESS,
            priceAdapter: USDC_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER,
            creditRatio: USDC_MARKET_MAKING_ENGINE_CREDIT_RATIO,
            isEnabled: USDC_MARKET_MAKING_ENGINE_IS_ENABLED,
            decimals: USDC_MARKET_MAKING_ENGINE_DECIMALS
        });
        marketMakingEngineCollaterals[USDC_MARKET_MAKING_ENGINE_COLLATERAL_ID] = usdcConfig;

        MarketMakingEngineCollateral memory wBtcConfig = MarketMakingEngineCollateral({
            collateral: WBTC_MARKET_MAKING_ENGINE_ADDRESS,
            priceAdapter: WBTC_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER,
            creditRatio: WBTC_MARKET_MAKING_ENGINE_CREDIT_RATIO,
            isEnabled: WBTC_MARKET_MAKING_ENGINE_IS_ENABLED,
            decimals: WBTC_MARKET_MAKING_ENGINE_DECIMALS
        });
        marketMakingEngineCollaterals[WBTC_MARKET_MAKING_ENGINE_COLLATERAL_ID] = wBtcConfig;

        MarketMakingEngineCollateral memory wEthConfig = MarketMakingEngineCollateral({
            collateral: WETH_MARKET_MAKING_ENGINE_ADDRESS,
            priceAdapter: WETH_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER,
            creditRatio: WETH_MARKET_MAKING_ENGINE_CREDIT_RATIO,
            isEnabled: WETH_MARKET_MAKING_ENGINE_IS_ENABLED,
            decimals: WETH_MARKET_MAKING_ENGINE_DECIMALS
        });
        marketMakingEngineCollaterals[WETH_MARKET_MAKING_ENGINE_COLLATERAL_ID] = wEthConfig;

        MarketMakingEngineCollateral memory wstEthConfig = MarketMakingEngineCollateral({
            collateral: WSTETH_MARKET_MAKING_ENGINE_ADDRESS,
            priceAdapter: WSTETH_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER,
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
