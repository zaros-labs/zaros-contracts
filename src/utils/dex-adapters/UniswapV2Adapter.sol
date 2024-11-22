// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { SwapExactInputSinglePayload, SwapExactInputPayload } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { IUniswapV2Router02 } from "@zaros/utils/interfaces/IUniswapV2Router02.sol";
import { ISwapAssetConfig } from "@zaros/utils/interfaces/ISwapAssetConfig.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";
import { Path } from "@zaros/utils/libraries/Path.sol";

// Open zeppelin upgradeable dependencies
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice Uniswap V2 adapter contract
contract UniswapV2Adapter is UUPSUpgradeable, OwnableUpgradeable, IDexAdapter {
    using Path for bytes;

    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when the deadline is set
    /// @param deadline The new deadline
    event LogSetDeadline(uint256 deadline);

    /// @notice Event emitted when the pool fee is set
    /// @param newFee The new pool fee
    event LogSetPoolFee(uint24 newFee);

    /// @notice Event emitted when the slippage tolerance is set
    /// @param newSlippageTolerance The new slippage tolerance
    event LogSetSlippageTolerance(uint256 newSlippageTolerance);

    /// @notice Event emitted when the new swap asset config data is set
    /// @param asset The asset address
    /// @param decimals The asset decimals
    /// @param priceAdapter The asset price adapter
    event LogSetSwapAssetConfig(address indexed asset, uint8 decimals, address priceAdapter);

    /// @notice Event emitted when the Uniswap V2 Swap Strategy Router is set
    /// @param uniswapV2SwapStrategyRouter The Uniswap V2 Swap Strategy Router address
    event LogSetUniswapV2SwapStrategyRouter(address indexed uniswapV2SwapStrategyRouter);

    /// @notice todo
    event LogSetSwapAssetConfigAddress(address indexed swapAssetConfig);

    /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Uniswap V2 Swap Strategy Router address
    address public uniswapV2SwapStrategyRouter;

    /// @notice todo
    address public swapAssetConfig;

    /// @notice the slippage tolerance
    /// @dev the minimum is 100 (e.g. 1%)
    uint256 public slippageToleranceBps;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Uniswap V2 Swap Strategy ID
    uint128 public constant UNISWAP_V2_SWAP_STRATEGY_ID = 2;

    /*//////////////////////////////////////////////////////////////////////////
                                    INITIALIZE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner,
        address _uniswapV2SwapStrategyRouter,
        address _swapAssetConfig,
        uint256 _slippageToleranceBps
    )
        external
        initializer
    {
        // initialize the owner
        __Ownable_init(owner);

        // set the Uniswap V2 Swap Strategy Router
        setUniswapV2SwapStrategyRouter(_uniswapV2SwapStrategyRouter);

        // set the swap asset config
        setSwapAssetConfig(_swapAssetConfig);

        // set the slippage tolerance
        setSlippageTolerance(_slippageToleranceBps);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IDexAdapter
    function executeSwapExactInputSingle(SwapExactInputSinglePayload calldata swapPayload)
        external
        returns (uint256 amountOut)
    {
        // transfer the tokenIn from the send to this contract
        IERC20(swapPayload.tokenIn).transferFrom(msg.sender, address(this), swapPayload.amountIn);

        // aprove the tokenIn to the swap router
        IERC20(swapPayload.tokenIn).approve(uniswapV2SwapStrategyRouter, swapPayload.amountIn);

        // get the expected output amount
        uint256 expectedAmountOut = ISwapAssetConfig(swapAssetConfig).getExpectedOutput(
            swapPayload.tokenIn, swapPayload.tokenOut, swapPayload.amountIn
        );

        // Calculate the minimum acceptable output based on the slippage tolerance
        uint256 amountOutMinimum =
            (expectedAmountOut * (Constants.BPS_DENOMINATOR - slippageToleranceBps)) / Constants.BPS_DENOMINATOR;

        address[] memory path;
        path[0] = swapPayload.tokenIn;
        path[1] = swapPayload.tokenOut;

        uint256[] memory amountsOut = IUniswapV2Router02(uniswapV2SwapStrategyRouter).swapExactTokensForTokens({
            amountIn: swapPayload.amountIn,
            amountOutMin: amountOutMinimum,
            path: path,
            to: swapPayload.recipient,
            deadline: block.timestamp + 30
        });

        return amountsOut[1];
    }

    /// @inheritdoc IDexAdapter
    function executeSwapExactInput(SwapExactInputPayload calldata swapPayload) external returns (uint256 amountOut) {
        // transfer the tokenIn from the send to this contract
        IERC20(swapPayload.tokenIn).transferFrom(msg.sender, address(this), swapPayload.amountIn);

        // aprove the tokenIn to the swap router
        IERC20(swapPayload.tokenIn).approve(uniswapV2SwapStrategyRouter, swapPayload.amountIn);

        // get the expected output amount
        uint256 expectedAmountOut = ISwapAssetConfig(swapAssetConfig).getExpectedOutput(
            swapPayload.tokenIn, swapPayload.tokenOut, swapPayload.amountIn
        );

        // Calculate the minimum acceptable output based on the slippage tolerance
        uint256 amountOutMinimum =
            (expectedAmountOut * (Constants.BPS_DENOMINATOR - slippageToleranceBps)) / Constants.BPS_DENOMINATOR;

        // decode path as it is Uniswap V3 specific
        (address[] memory tokens,) = swapPayload.path.decodePath();

        // execute trade
        uint256[] memory amountsOut = IUniswapV2Router02(uniswapV2SwapStrategyRouter).swapExactTokensForTokens({
            amountIn: swapPayload.amountIn,
            amountOutMin: amountOutMinimum,
            path: tokens,
            to: swapPayload.recipient,
            deadline: block.timestamp + 30
        });

        // return the amount out of the last trade
        return amountsOut[tokens.length];
     }

    /// @notice Sets slippage tolerance
    /// @dev the minimum is 100 (e.g. 1%)
    function setSlippageTolerance(uint256 newSlippageTolerance) public onlyOwner {
        // revert if the new slippage tolerance is less than 100
        slippageToleranceBps = newSlippageTolerance;

        // emit the event LogSetSlippageTolerance
        emit LogSetSlippageTolerance(newSlippageTolerance);
    }

    /// @notice Sets the Uniswap V2 Swap Strategy Router
    /// @dev Only the owner can set the Uniswap V2 Swap Strategy Router
    /// @param _uniswapV2SwapStrategyRouter The Uniswap V2 Swap Strategy Router address
    function setUniswapV2SwapStrategyRouter(address _uniswapV2SwapStrategyRouter) public onlyOwner {
        if (_uniswapV2SwapStrategyRouter == address(0)) revert Errors.ZeroInput("_uniswapV2SwapStrategyRouter");

        // set the uniswap v2 swap strategy router
        uniswapV2SwapStrategyRouter = _uniswapV2SwapStrategyRouter;

        // emit the event
        emit LogSetUniswapV2SwapStrategyRouter(_uniswapV2SwapStrategyRouter);
    }

    /// @notice Sets the swap asset config address
    /// @param _swapAssetConfig The swap asset config address
    function setSwapAssetConfig(address _swapAssetConfig) public onlyOwner {
        if (_swapAssetConfig == address(0)) revert Errors.ZeroInput("_swapAssetConfig");

        // set the swap Asset Config address
        swapAssetConfig = _swapAssetConfig;

        // emit the event
        emit LogSetSwapAssetConfigAddress(_swapAssetConfig);
    }
    /*//////////////////////////////////////////////////////////////////////////
                                    UPGRADEABLE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Upgrades the contract
    /// @dev This function is called by the proxy when the contract is upgraded
    /// @dev Only the owner can upgrade the contract
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
