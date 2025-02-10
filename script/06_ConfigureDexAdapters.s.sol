// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "script/utils/ProtocolConfiguration.sol";
import { SwapAssetConfigData } from "@zaros/utils/dex-adapters/BaseAdapter.sol";
import { MockUniswapV3SwapStrategyRouter } from "test/mocks/MockUniswapV3SwapStrategyRouter.sol";
import { MockUniswapV2SwapStrategyRouter } from "test/mocks/MockUniswapV2SwapStrategyRouter.sol";
import { MockCurveStrategyRouter } from "test/mocks/MockCurveStrategyRouter.sol";
import { LimitedMintingERC20 } from "testnet/LimitedMintingERC20.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract ConfigureDexAdapters is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal perpsEngineUsdToken;
    address internal wEth;
    address internal usdc;
    address internal wBtc;
    address internal wstEth;
    address internal uniswapV3SwapStrategyRouter;
    address internal uniswapV2SwapStrategyRouter;
    address internal curveSwapStrategyRouter;
    address internal uniswapV3Adapter;
    address internal uniswapV2Adapter;
    address internal curveAdapter;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/
    IMarketMakingEngine internal marketMakingEngine;

    function run(bool isTestnet) public broadcaster {
        marketMakingEngine = IMarketMakingEngine(vm.envAddress("MARKET_MAKING_ENGINE"));
        wEth = vm.envAddress("WETH");
        usdc = vm.envAddress("USDC");
        wBtc = vm.envAddress("WBTC");
        wstEth = vm.envAddress("WSTETH");
        uniswapV3SwapStrategyRouter = vm.envAddress("UNISWAP_V3_SWAP_STRATEGY_ROUTER");
        uniswapV2SwapStrategyRouter = vm.envAddress("UNISWAP_V2_SWAP_STRATEGY_ROUTER");
        curveSwapStrategyRouter = vm.envAddress("CURVE_SWAP_STRATEGY_ROUTER");

        console.log("**************************");
        console.log("Environment variables:");
        console.log("Market Making Engine: ", address(marketMakingEngine));
        console.log("wEth: ", wEth);
        console.log("USDC: ", usdc);
        console.log("wBtc: ", wBtc);
        console.log("wstEth: ", wstEth);
        console.log("uniswapV3SwapStrategyRouter: ", uniswapV3SwapStrategyRouter);
        console.log("uniswapV2SwapStrategyRouter: ", uniswapV2SwapStrategyRouter);
        console.log("curveSwapStrategyRouter: ", curveSwapStrategyRouter);
        console.log("**************************");

        address[] memory collaterals = new address[](4);
        collaterals[0] = address(usdc);
        collaterals[1] = address(wEth);
        collaterals[2] = address(wBtc);
        collaterals[3] = address(wstEth);

        SwapAssetConfigData[] memory collateralData = new SwapAssetConfigData[](5);

        collateralData[0] = SwapAssetConfigData({
            decimals: marginCollaterals[USDC_MARGIN_COLLATERAL_ID].tokenDecimals,
            priceAdapter: address(marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceAdapter)
        });

        collateralData[1] = SwapAssetConfigData({
            decimals: marginCollaterals[WETH_MARGIN_COLLATERAL_ID].tokenDecimals,
            priceAdapter: address(marginCollaterals[WETH_MARGIN_COLLATERAL_ID].priceAdapter)
        });

        collateralData[2] = SwapAssetConfigData({
            decimals: marginCollaterals[WBTC_MARGIN_COLLATERAL_ID].tokenDecimals,
            priceAdapter: address(marginCollaterals[WBTC_MARGIN_COLLATERAL_ID].priceAdapter)
        });

        collateralData[3] = SwapAssetConfigData({
            decimals: marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].tokenDecimals,
            priceAdapter: address(marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].priceAdapter)
        });

        if (isTestnet) {
            uniswapV3SwapStrategyRouter = address(new MockUniswapV3SwapStrategyRouter());
            uniswapV2SwapStrategyRouter = address(new MockUniswapV2SwapStrategyRouter());
            curveSwapStrategyRouter = address(new MockCurveStrategyRouter());
        }

        console.log("**************************");
        console.log("Configuring Uniswap V3 Adapter...");
        console.log("**************************");

        deployUniswapV3Adapter(
            marketMakingEngine,
            deployer,
            uniswapV3SwapStrategyRouter,
            SLIPPAGE_TOLERANCE_BPS,
            UNI_V3_FEE,
            collaterals,
            collateralData
        );

        console.log("Success! Uniswap V3 Adapter configured.");
        console.log("\n");

        console.log("**************************");
        console.log("Configuring Uniswap V2 Adapter...");
        console.log("**************************");

        deployUniswapV2Adapter(
            marketMakingEngine,
            deployer,
            uniswapV2SwapStrategyRouter,
            SLIPPAGE_TOLERANCE_BPS,
            collaterals,
            collateralData
        );

        console.log("Success! Uniswap V2 Adapter configured.");
        console.log("\n");

        console.log("**************************");
        console.log("Configuring Curve Adapter...");
        console.log("**************************");

        deployCurveAdapter(
            marketMakingEngine, deployer, curveSwapStrategyRouter, SLIPPAGE_TOLERANCE_BPS, collaterals, collateralData
        );

        console.log("Success! Curve Adapter configured.");
        console.log("\n");

        if (isTestnet) {
            for (uint256 i; i < collaterals.length; i++) {
                LimitedMintingERC20(collaterals[i]).mint(uniswapV3Adapter, type(uint256).max);
                LimitedMintingERC20(collaterals[i]).mint(uniswapV2Adapter, type(uint256).max);
                LimitedMintingERC20(collaterals[i]).mint(curveAdapter, type(uint256).max);
            }
        }
    }
}
