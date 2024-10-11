// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { UniswapV3Adapter } from "@zaros/utils/dex-adapters/UniswapV3Adapter.sol";
import { MockUniswapV3SwapStrategyRouter } from "test/mocks/MockUniswapV3SwapStrategyRouter.sol";
import { IMarketMakingEngine } from "@zaros/market-making/MarketMakingEngine.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

library DexAdapterUtils {
    function deployUniswapV3Adapter(
        IMarketMakingEngine marketMakingEngine,
        address owner,
        uint256 slippageTolerance,
        uint24 fee,
        bool isTest
    )
        internal
        returns (UniswapV3Adapter uniswapV3Adapter)
    {
        // instatiate the Uniswap V3 Adapter Implementation
        UniswapV3Adapter uniswapV3AdapterImplementation = new UniswapV3Adapter();

        // create bytes of the initialze function of Uniswap V3 Adapter Implementation
        bytes memory initializeUniswapV3Adapter =
            abi.encodeWithSelector(uniswapV3AdapterImplementation.initialize.selector, owner, slippageTolerance, fee);

        // deploy the Uniswap V3 Adapter Proxy
        uniswapV3Adapter = UniswapV3Adapter(
            address(new ERC1967Proxy(address(uniswapV3AdapterImplementation), initializeUniswapV3Adapter))
        );

        if (isTest) {
            // instantiate the mock of Uniswap V3 Swap Strategy Router
            MockUniswapV3SwapStrategyRouter mockUniswapV3SwapStrategyRouter = new MockUniswapV3SwapStrategyRouter();

            // set the mock Uniswap V3 Swap Strategy Router in the Uniswap V3 Adapter Proxy
            uniswapV3Adapter.setMockUniswapV3SwapStrategyRouter(address(mockUniswapV3SwapStrategyRouter));

            // set the use of the mock Uniswap V3 Swap Strategy Router in the Uniswap V3 Adapter Proxy
            uniswapV3Adapter.setUseMockUniswapV3SwapStrategyRouter(true);
        }

        // configure the Dex Swap Strategy in the Market Making Engine
        marketMakingEngine.configureDexSwapStrategy(
            uniswapV3Adapter.UNISWAP_V3_SWAP_STRATEGY_ID(), address(uniswapV3Adapter)
        );

        console.log("UniswapV3Adapter deployed at: %s", address(uniswapV3Adapter));
    }
}
