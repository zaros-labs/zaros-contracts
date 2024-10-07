// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Uniswap dependencies
import { ISwapRouter } from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

// Zaros dependencies
import { DexSwapStrategy } from "@zaros/market-making/leaves/DexSwapStrategy.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { ChainlinkUtil } from "@zaros/external/chainlink/ChainlinkUtil.sol";
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { IERC20Metadata } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice Uniswap V3 Swap Strategy contract
abstract contract UniswapV3SwapStrategy {
    using DexSwapStrategy for DexSwapStrategy.Data;

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Uniswap V3 Swap Strategy address
    address internal constant UNISWAP_V3_SWAP_STRATEGY_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    /// @notice Uniswap V3 Swap Strategy ID
    uint128 internal constant UNISWAP_V3_SWAP_STRATEGY_ID = 1;

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Support function to swap tokens using UniswapV3
    /// @param tokenIn the token to be swapped
    /// @param amountIn the amount of the tokenIn to be swapped
    /// @param tokenOut the token to be received
    /// @param deadline the deadline for the swap
    /// @param recipient the address to receive the tokenOut
    /// @return amountOut the amount to be received
    function swapExactTokens(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 deadline,
        address recipient
    )
        internal
        returns (uint256 amountOut)
    {
        DexSwapStrategy.Data storage dexSwapStrategy = DexSwapStrategy.load(UNISWAP_V3_SWAP_STRATEGY_ID);

        // Perform the swap using Uniswap V3 SwapRouter
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: 0,
            recipient: recipient,
            deadline: deadline,
            amountIn: amountIn,
            amountOutMinimum: _calculateAmountOutMinimum(tokenIn, amountIn, tokenOut, 0),
            sqrtPriceLimitX96: 0
        });

        // The call to `exactInputSingle` executes the swap.
        amountOut = ISwapRouter(UNISWAP_V3_SWAP_STRATEGY_ROUTER).exactInputSingle(params);
    }

    /// @notice Support function to calculate the minimum amount of tokens to be received
    /// @param tokenIn The token to be swapped
    /// @param amount The amount of the tokenIn be swapped
    /// @param tokenOut The token to be received
    /// @param slippageTolerance The maximum amount that can be lost in a trade
    /// @return amountOutMinimum The minimum amount to be received in a trade
    function _calculateAmountOutMinimum(
        address tokenIn,
        uint256 amount,
        address tokenOut,
        uint256 slippageTolerance
    )
        internal
        view
        returns (uint256 amountOutMinimum)
    {
        // Check if price adapters are defined
        if (
            Collateral.load(tokenIn).priceAdapter == address(0)
                || Collateral.load(tokenOut).priceAdapter == address(0)
        ) {
            revert Errors.PriceAdapterUndefined();
        }

        // Load sequencer uptime feed based on chain ID
        address sequencerUptimeFeed =
            MarketMakingEngineConfiguration.load().sequencerUptimeFeedByChainId[block.chainid];

        ChainlinkUtil.GetPriceParams memory paramsIn = ChainlinkUtil.GetPriceParams({
            priceFeed: IAggregatorV3(Collateral.load(tokenIn).priceAdapter),
            priceFeedHeartbeatSeconds: Collateral.load(tokenIn).priceFeedHeartbeatSeconds,
            sequencerUptimeFeed: IAggregatorV3(sequencerUptimeFeed)
        });

        ChainlinkUtil.GetPriceParams memory paramsOut = ChainlinkUtil.GetPriceParams({
            priceFeed: IAggregatorV3(Collateral.load(tokenOut).priceAdapter),
            priceFeedHeartbeatSeconds: Collateral.load(tokenOut).priceFeedHeartbeatSeconds,
            sequencerUptimeFeed: IAggregatorV3(sequencerUptimeFeed)
        });

        // Get prices for tokens
        UD60x18 tokeInUSDPrice = ChainlinkUtil.getPrice(paramsIn);
        UD60x18 tokenOutUSDPrice = ChainlinkUtil.getPrice(paramsOut);

        // tokenIn / tokenOut price ratio
        UD60x18 priceRatio = tokeInUSDPrice.div(tokenOutUSDPrice);

        // Adjust for token decimals
        uint8 decimalsTokenIn = IERC20Metadata(tokenIn).decimals();
        uint8 decimalsTokenOut = IERC20Metadata(tokenOut).decimals();
        if (decimalsTokenIn != decimalsTokenOut) {
            uint256 decimalFactor;
            if (decimalsTokenIn > decimalsTokenOut) {
                decimalFactor = 10 ** uint256(decimalsTokenIn - decimalsTokenOut);
                amount = amount / decimalFactor;
            } else {
                decimalFactor = 10 ** uint256(decimalsTokenOut - decimalsTokenIn);
                amount = amount * decimalFactor;
            }
        }

        // Calculate adjusted amount to receive based on price ratio
        UD60x18 fullAmountToReceive = ud60x18(amount).mul(priceRatio);

        // The minimum percentage from the full amount to receive
        // (e.g. if slippageTolerance is 100 BPS, the minAmountToReceiveInBPS will be 9900 BPS )
        UD60x18 minAmountToReceiveInBPS = (ud60x18(DexSwapStrategy.BPS_DENOMINATOR).sub(ud60x18(slippageTolerance)));

        // Adjust for slippageTolerance and convert to uint256
        amountOutMinimum = fullAmountToReceive.mul(minAmountToReceiveInBPS).div(
            ud60x18(DexSwapStrategy.BPS_DENOMINATOR)
        ).intoUint256();
    }
}
