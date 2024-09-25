// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { ChainlinkUtil } from "@zaros/external/chainlink/ChainlinkUtil.sol";
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";

// Uniswap dependecies
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

// Open Zeppelin dependencies
import { IERC20Metadata } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

library SwapStrategy {
    /// @notice ERC7201 storage location.
    bytes32 internal constant SWAP_STRATEGY_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.SwapStrategy")) - 1));

    uint256 internal constant BPS_DENOMINATOR = 10_000;
    uint256 internal constant MIN_POOL_FEE = 1000;
    uint256 internal constant MIN_SLIPPAGE_TOLERANCE = 100;

    /// @param swapRouter The UniswapV3 ISwapRouter contract address used for executing swaps.
    /// @param poolFee The fee tier of the Uniswap pool to be used for swaps, measured in basis points.
    /// @param slippageTolerance The maximum slippage allowed for a swap, expressed in basis points (1% = 100 basis points).
    struct Data {
        ISwapRouter swapRouter;
        uint24 poolFee;
        uint256 slippageTolerance;
    }

    /// @notice Loads a {SwapStrategy}.
    /// @return swapStrategy The loaded swap strategy storage pointer.
    function load() internal pure returns (Data storage swapStrategy) {
        bytes32 slot = keccak256(abi.encode(SWAP_STRATEGY_LOCATION));
        assembly {
            swapStrategy.slot := slot
        }
    }

    /// @notice Sets uniswap router address required for swapping tokens
    /// @return bool returns true if succesfully set
    function setUniswapRouterAddress(Data storage self, address routerAddress) internal returns(bool) {
        if(routerAddress == address(0)) revert Errors.ZeroInput("swapRouter address");
        self.swapRouter = ISwapRouter(routerAddress);

        return true;
    }

    /// @notice Sets the pool fee
    /// @dev the minimum is 1000 (e.g. 0.1%)
    function setPoolFee(Data storage self, uint24 newFee) internal {
        if(newFee < MIN_POOL_FEE) revert Errors.InvalidPoolFee();
        self.poolFee = newFee;
    }
    /// @notice Sets the slippage tolerance
    /// @dev the minimum is 100 (e.g. 1%)
    function setSlippageTolerance(Data storage self, uint256 newSlippageTolerance) internal {
        if(newSlippageTolerance < MIN_SLIPPAGE_TOLERANCE) revert Errors.InvalidSlippage();
        self.slippageTolerance = newSlippageTolerance;
    }

    /// @notice Support function to swap tokens using UniswapV3
    /// @param tokenIn the token to be swapped
    /// @param amountIn the amount of the tokenIn to be swapped
    /// @param tokenOut the token to be received
    /// @return amountOut the amount to be received
    function swapExactTokens(
        Data storage self,
        address tokenIn,
        uint256 amountIn,
        address tokenOut
    )
        internal
        returns (uint256 amountOut)
    {

        // Check if Uniswap Address is set
        if(self.swapRouter == ISwapRouter(address(0))) revert Errors.ZeroInput("swapRouter address");

        // Approve the router to spend DAI.
        TransferHelper.safeApprove(tokenIn, address(self.swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: self.poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 
                SwapStrategy._calculateAmountOutMinimum(tokenIn, amountIn, tokenOut, self.slippageTolerance),
            sqrtPriceLimitX96: 0
        });

        // The call to `exactInputSingle` executes the swap.
        amountOut = self.swapRouter.exactInputSingle(params);
    }

    /// @notice Support function to calculate the minimum amount of tokens to be received
    /// @param tokenIn The token to be swapped
    /// @param amount The amount of the tokenIn be swapped
    /// @param tokenOut The token to be received
    /// @param slippage The maximum amount that can be lost in a trade
    /// @param amountOutMinimum The minimum amount to be received in a trade
    function _calculateAmountOutMinimum(
        address tokenIn,
        uint256 amount,
        address tokenOut,
        uint256 slippage
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
        // (e.g. if slippage is 100 BPS, the minAmountToReceiveInBPS will be 9900 BPS )
        UD60x18 minAmountToReceiveInBPS = (ud60x18(BPS_DENOMINATOR).sub(ud60x18(slippage)));

        // Adjust for slippage and convert to uint256
        amountOutMinimum =
            fullAmountToReceive.mul(minAmountToReceiveInBPS).div(ud60x18(BPS_DENOMINATOR)).intoUint256();
    }
}
