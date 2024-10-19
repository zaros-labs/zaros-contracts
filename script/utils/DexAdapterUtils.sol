// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { UniswapV3Adapter } from "@zaros/utils/dex-adapters/UniswapV3Adapter.sol";
import { MockUniswapV3SwapStrategyRouter } from "test/mocks/MockUniswapV3SwapStrategyRouter.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

/// @notice Dex Adapter Utils
library DexAdapterUtils {
    /// @notice Deploys the Uniswap V3 Adapter
    /// @param marketMakingEngine The Market Making Engine
    /// @param owner The owner of the Uniswap V3 Adapter
    /// @param slippageToleranceBps The slippage tolerance
    /// @param fee The Uniswap V3 pool fee
    /// @param collaterals The collaterals to set in the Uniswap V3 Adapter
    /// @param collateralData The collateral data to set in the Uniswap V3 Adapter
    /// @param isTest If the Uniswap V3 Adapter is for testing purposes
    function deployUniswapV3Adapter(
        IMarketMakingEngine marketMakingEngine,
        address owner,
        uint256 slippageToleranceBps,
        uint24 fee,
        address[] memory collaterals,
        UniswapV3Adapter.CollateralData[] memory collateralData,
        bool isTest
    )
        internal
        returns (UniswapV3Adapter uniswapV3Adapter)
    {
        // revert if the length of collaterals and collateralData is different
        if (collaterals.length != collateralData.length) {
            revert Errors.ArrayLengthMismatch(collaterals.length, collateralData.length);
        }

        // instatiate the Uniswap V3 Adapter Implementation
        UniswapV3Adapter uniswapV3AdapterImplementation = new UniswapV3Adapter();

        // create bytes of the initialze function of Uniswap V3 Adapter Implementation
        bytes memory initializeUniswapV3Adapter =
            abi.encodeWithSelector(uniswapV3AdapterImplementation.initialize.selector, owner, slippageToleranceBps, fee);

        // deploy the Uniswap V3 Adapter Proxy
        uniswapV3Adapter = UniswapV3Adapter(
            address(new ERC1967Proxy(address(uniswapV3AdapterImplementation), initializeUniswapV3Adapter))
        );

        console.log("UniswapV3Adapter deployed at: %s", address(uniswapV3Adapter));

        if (isTest) {
            // instantiate the mock of Uniswap V3 Swap Strategy Router
            MockUniswapV3SwapStrategyRouter mockUniswapV3SwapStrategyRouter = new MockUniswapV3SwapStrategyRouter();

            // set the mock Uniswap V3 Swap Strategy Router in the Uniswap V3 Adapter Proxy
            uniswapV3Adapter.setMockUniswapV3SwapStrategyRouter(address(mockUniswapV3SwapStrategyRouter));

            // set the use of the mock Uniswap V3 Swap Strategy Router in the Uniswap V3 Adapter Proxy
            uniswapV3Adapter.setUseMockUniswapV3SwapStrategyRouter(true);
        }

        for (uint256 i; i < collaterals.length; i++) {
            // set the collateral data in the Uniswap V3 Adapter Proxy
            uniswapV3Adapter.setCollateralData(
                collaterals[i], collateralData[i].decimals, collateralData[i].priceAdapter
            );

            console.log(
                "Collateral data set in UniswapV3Adapter: collateral: %s, decimals: %s, priceAdapter: %s",
                collaterals[i],
                collateralData[i].decimals,
                collateralData[i].priceAdapter
            );
        }

        // configure the Dex Swap Strategy in the Market Making Engine
        marketMakingEngine.configureDexSwapStrategy(
            uniswapV3Adapter.UNISWAP_V3_SWAP_STRATEGY_ID(), address(uniswapV3Adapter)
        );

        console.log(
            "Uniswap V3 Swap Strategy configured in MarketMakingEngine: strategyId: %s, strategyAddress: %s",
            uniswapV3Adapter.UNISWAP_V3_SWAP_STRATEGY_ID(),
            address(uniswapV3Adapter)
        );
    }
}
