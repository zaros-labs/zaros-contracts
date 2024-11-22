// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { SwapExactInputSinglePayload, SwapExactInputPayload } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { ICurveSwapRouter } from "@zaros/utils/interfaces/ICurveSwapRouter.sol";
import { ICurveRegistry } from "@zaros/utils/interfaces/ICurveRegistry.sol";
import { ISwapAssetConfig } from "@zaros/utils/interfaces/ISwapAssetConfig.sol";
import { ICurvePool } from "@zaros/utils/interfaces/ICurvePool.sol";
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

/// @notice Curve Finance adapter contract
contract CurveAdapter is UUPSUpgradeable, OwnableUpgradeable, IDexAdapter {
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
    /// @param curveSwapRouter The Uniswap V2 Swap Strategy Router address
    event LogSetCurveStrategyRouter(address indexed curveSwapRouter);

    /// @notice todo
    event LogSetCurveRegistry(address indexed curveRegistry);

    /// @notice todo
    event LogSetSwapAssetConfigAddress(address indexed swapAssetConfig);

    /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Curve Strategy Router address
    address public curveStrategyRouter;

    /// @notice todo
    address public swapAssetConfig;

    /// @notice todo
    ICurveRegistry public curveRegistry;

    /// @notice the slippage tolerance
    /// @dev the minimum is 100 (e.g. 1%)
    uint256 public slippageToleranceBps;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Curve Swap Strategy ID
    uint128 public constant CURVE_SWAP_STRATEGY_ID = 3;

    /*//////////////////////////////////////////////////////////////////////////
                                    INITIALIZE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner,
        address _curveStrategyRouter,
        address _curveRegistry,
        address _swapAssetConfig,
        uint256 _slippageToleranceBps
    )
        external
        initializer
    {
        // initialize the owner
        __Ownable_init(owner);

        // set the Curve Swap Strategy Router
        setCurveStrategyRouter(_curveStrategyRouter);

        // set the curve registry
        setCurveRegistry(_curveRegistry);

        // set the swap asset config
        setSwapAssetConfig(_swapAssetConfig);

        // set the slippage tolerance
        setSlippageTolerance(_slippageToleranceBps);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Executes a swap using the exact input single amount, coming from the swap payload passed by the Market
    /// Making Engine.
    /// @return amountOut The amount out returned.
    function executeSwapExactInputSingle(SwapExactInputSinglePayload memory swapPayload)
        external
        returns (uint256 amountOut)
    {
        // transfer the tokenIn from the send to this contract
        IERC20(swapPayload.tokenIn).transferFrom(msg.sender, address(this), swapPayload.amountIn);

        // approve the tokenIn to the swap router
        IERC20(swapPayload.tokenIn).approve(curveStrategyRouter, swapPayload.amountIn);

        // get the expected output amount
        uint256 expectedAmountOut = ISwapAssetConfig(swapAssetConfig).getExpectedOutput(
            swapPayload.tokenIn, swapPayload.tokenOut, swapPayload.amountIn
        );

        // Calculate the minimum acceptable output based on the slippage tolerance
        uint256 amountOutMinimum =
            (expectedAmountOut * (Constants.BPS_DENOMINATOR - slippageToleranceBps)) / Constants.BPS_DENOMINATOR;

        return ICurveSwapRouter(curveStrategyRouter).exchange_with_best_rate({
            _from: swapPayload.tokenIn,
            _to: swapPayload.tokenOut,
            _amount: swapPayload.amountIn,
            _expected: amountOutMinimum,
            _receiver: swapPayload.recipient
        });
    }

    /// @notice Executes a swap using the exact input amount, coming from the swap payload passed by the Market Making
    /// Engine.
    /// @return amountOut The amount out returned.
    function executeSwapExactInput(SwapExactInputPayload calldata swapPayload) external returns (uint256 amountOut) {
        // transfer the tokenIn from the send to this contract
        IERC20(swapPayload.tokenIn).transferFrom(msg.sender, address(this), swapPayload.amountIn);

        // decode path as it is Uniswap V3 specific
        (address[] memory tokens,) = swapPayload.path.decodePath();

        // declare amountIn as initial token amountIn
        uint256 amountIn = swapPayload.amountIn;

        for (uint256 i; i < tokens.length - 1; i++) {
            // approve the tokenIn to the swap router
            IERC20(tokens[i]).approve(curveStrategyRouter, amountIn);

            // get the expected output amount
            uint256 expectedAmountOut =
                ISwapAssetConfig(swapAssetConfig).getExpectedOutput(tokens[i], tokens[i + 1], amountIn);

            // Calculate the minimum acceptable output based on the slippage tolerance
            uint256 amountOutMinimum =
                (expectedAmountOut * (Constants.BPS_DENOMINATOR - slippageToleranceBps)) / Constants.BPS_DENOMINATOR;

            // If last swap send received tokens to payload recipient
            address receiver = (i == tokens.length - 2) ? swapPayload.recipient : address(this);

            // make single exchange
            amountIn = ICurveSwapRouter(curveStrategyRouter).exchange_with_best_rate({
                _from: tokens[i],
                _to: tokens[i + 1],
                _amount: amountIn,
                _expected: amountOutMinimum,
                _receiver: receiver
            });
        }

        // return the last amountIn value which is basically the amountOut
        amountOut = amountIn;
    }

    /// @notice Sets slippage tolerance
    /// @dev the minimum is 100 (e.g. 1%)
    function setSlippageTolerance(uint256 newSlippageTolerance) public onlyOwner {
        // revert if the new slippage tolerance is less than 100
        slippageToleranceBps = newSlippageTolerance;

        // emit the event LogSetSlippageTolerance
        emit LogSetSlippageTolerance(newSlippageTolerance);
    }

    /// @notice Sets the Curve Strategy Router
    /// @dev Only the owner can set the Curve Strategy Router
    /// @param _curveStrategyRouter The Curve Strategy Router address
    function setCurveStrategyRouter(address _curveStrategyRouter) public onlyOwner {
        if (_curveStrategyRouter == address(0)) revert Errors.ZeroInput("_curveStrategyRouter");

        // set the curve swap strategy router
        curveStrategyRouter = _curveStrategyRouter;

        // emit the event
        emit LogSetCurveStrategyRouter(_curveStrategyRouter);
    }

    /// @notice Sets the Curve Registry
    /// @dev Only the owner can set the Curve Strategy Router
    /// @param _curveRegistry The Curve Strategy Router address
    function setCurveRegistry(address _curveRegistry) public onlyOwner {
        if (_curveRegistry == address(0)) revert Errors.ZeroInput("_curveRegistry");

        // set the curve swap strategy router
        curveRegistry = ICurveRegistry(_curveRegistry);

        // emit the event
        emit LogSetCurveRegistry(_curveRegistry);
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
