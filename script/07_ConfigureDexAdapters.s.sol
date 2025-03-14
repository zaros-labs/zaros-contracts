// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { BaseScript } from "./Base.s.sol";
import { ProtocolConfiguration } from "script/utils/ProtocolConfiguration.sol";
import { SwapAssetConfigData } from "@zaros/utils/dex-adapters/BaseAdapter.sol";
import { MockUniswapV3SwapStrategyRouter } from "test/mocks/MockUniswapV3SwapStrategyRouter.sol";
import { MockUniswapV2SwapStrategyRouter } from "test/mocks/MockUniswapV2SwapStrategyRouter.sol";
import { MockCurveStrategyRouter } from "test/mocks/MockCurveStrategyRouter.sol";
import { LimitedMintingERC20 } from "testnet/LimitedMintingERC20.sol";
import { Constants } from "@zaros/utils/Constants.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

contract ConfigureDexAdapters is BaseScript, ProtocolConfiguration {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/
    address internal perpsEngineUsdToken;
    address internal wEth;
    address internal usdc;
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

    function run(bool shouldDeployMock) public broadcaster {
        marketMakingEngine = IMarketMakingEngine(vm.envAddress("MARKET_MAKING_ENGINE"));
        wEth = vm.envAddress("WETH");
        usdc = vm.envAddress("USDC");

        if (shouldDeployMock) {
            uniswapV3SwapStrategyRouter = address(new MockUniswapV3SwapStrategyRouter());
            uniswapV2SwapStrategyRouter = address(new MockUniswapV2SwapStrategyRouter());
            curveSwapStrategyRouter = address(new MockCurveStrategyRouter());
        } else {
            uniswapV3SwapStrategyRouter = vm.envAddress("UNISWAP_V3_SWAP_STRATEGY_ROUTER");
            uniswapV2SwapStrategyRouter = vm.envAddress("UNISWAP_V2_SWAP_STRATEGY_ROUTER");
            curveSwapStrategyRouter = vm.envAddress("CURVE_SWAP_STRATEGY_ROUTER");
        }

        console.log("**************************");
        console.log("Environment variables:");
        console.log("Market Making Engine: ", address(marketMakingEngine));
        console.log("wEth: ", wEth);
        console.log("USDC: ", usdc);
        console.log("shouldDeployMock: ", shouldDeployMock);
        console.log("uniswapV3SwapStrategyRouter: ", uniswapV3SwapStrategyRouter);
        console.log("uniswapV2SwapStrategyRouter: ", uniswapV2SwapStrategyRouter);
        console.log("curveSwapStrategyRouter: ", curveSwapStrategyRouter);
        console.log("CONSTANTS:");
        console.log("SLIPPAGE_TOLERANCE_BPS: ", SLIPPAGE_TOLERANCE_BPS);
        console.log("**************************");

        uint256 blockChainId = block.chainid;

        address[] memory collaterals = new address[](2);
        collaterals[0] = address(usdc);
        collaterals[1] = address(wEth);

        SwapAssetConfigData[] memory collateralData = new SwapAssetConfigData[](2);

        collateralData[0] = SwapAssetConfigData({
            decimals: USDC_MARKET_MAKING_ENGINE_DECIMALS,
            priceAdapter: blockChainId == Constants.ARB_SEPOLIA_CHAIN_ID
                ? USDC_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER
                : blockChainId == Constants.MONAD_TESTNET_CHAIN_ID
                    ? USDC_MONAD_TESTNET_MARKET_MAKING_ENGINE_PRICE_ADAPTER
                    : address(0)
        });

        collateralData[1] = SwapAssetConfigData({
            decimals: WETH_MARKET_MAKING_ENGINE_DECIMALS,
            priceAdapter: blockChainId == Constants.ARB_SEPOLIA_CHAIN_ID
                ? WETH_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER
                : blockChainId == Constants.MONAD_TESTNET_CHAIN_ID
                    ? WETH_MONAD_TESTNET_MARKET_MAKING_ENGINE_PRICE_ADAPTER
                    : address(0)
        });

        console.log("**************************");
        console.log("Configuring Uniswap V3 Adapter...");
        console.log("**************************");

        uniswapV3Adapter = address(
            deployUniswapV3Adapter(
                marketMakingEngine,
                deployer,
                uniswapV3SwapStrategyRouter,
                SLIPPAGE_TOLERANCE_BPS,
                UNI_V3_FEE,
                collaterals,
                collateralData
            )
        );

        console.log("Success! Uniswap V3 Adapter configured.");
        console.log("\n");

        console.log("**************************");
        console.log("Configuring Uniswap V2 Adapter...");
        console.log("**************************");

        uniswapV2Adapter = address(
            deployUniswapV2Adapter(
                marketMakingEngine,
                deployer,
                uniswapV2SwapStrategyRouter,
                SLIPPAGE_TOLERANCE_BPS,
                collaterals,
                collateralData
            )
        );

        console.log("Success! Uniswap V2 Adapter configured.");
        console.log("\n");

        console.log("**************************");
        console.log("Configuring Curve Adapter...");
        console.log("**************************");

        curveAdapter = address(
            deployCurveAdapter(
                marketMakingEngine,
                deployer,
                curveSwapStrategyRouter,
                SLIPPAGE_TOLERANCE_BPS,
                collaterals,
                collateralData
            )
        );

        console.log("Success! Curve Adapter configured.");
        console.log("\n");

        uint256 amountToMint = 100_000_000_000_000_000_000_000_000e18;

        if (shouldDeployMock) {
            for (uint256 i; i < collaterals.length; i++) {
                LimitedMintingERC20(collaterals[i]).mint(uniswapV3Adapter, amountToMint);
                LimitedMintingERC20(collaterals[i]).mint(uniswapV2Adapter, amountToMint);
                LimitedMintingERC20(collaterals[i]).mint(curveAdapter, amountToMint);
            }
        }
    }
}
