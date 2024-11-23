// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { SwapExactInputSinglePayload, SwapExactInputPayload } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { ICurveSwapRouter } from "@zaros/utils/interfaces/ICurveSwapRouter.sol";
import { ICurveRegistry } from "@zaros/utils/interfaces/ICurveRegistry.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { BaseAdapter } from "@zaros/utils/dex-adapters/BaseAdapter.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";
import { Path } from "@zaros/utils/libraries/Path.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice Curve Finance adapter contract
contract CurveAdapter is BaseAdapter {
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

    /// @notice Event emitted when the Uniswap V2 Swap Strategy Router is set
    /// @param curveSwapRouter The Uniswap V2 Swap Strategy Router address
    event LogSetCurveStrategyRouter(address indexed curveSwapRouter);

    /// @notice Event emitted when the Curve Strategy Router is set
    /// @param curveRegistry The Curve Strategy Router address
    event LogSetCurveRegistry(address indexed curveRegistry);

    /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Curve Strategy Router address
    address public curveStrategyRouter;

    /// @notice The curve registry address
    ICurveRegistry public curveRegistry;

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
        uint256 _slippageToleranceBps
    )
        external
        initializer
    {
        // initialize the owner
        __BaseAdapter_init(owner, _slippageToleranceBps);

        // set the Curve Swap Strategy Router
        setCurveStrategyRouter(_curveStrategyRouter);

        // set the curve registry
        setCurveRegistry(_curveRegistry);
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
        uint256 expectedAmountOut = getExpectedOutput(
            swapPayload.tokenIn, swapPayload.tokenOut, swapPayload.amountIn
        );

        // Calculate the minimum acceptable output based on the slippage tolerance
        uint256 amountOutMinimum = calculateAmountOutMin(expectedAmountOut);

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
            uint256 expectedAmountOut = getExpectedOutput(tokens[i], tokens[i + 1], amountIn);

            // Calculate the minimum acceptable output based on the slippage tolerance
            uint256 amountOutMinimum = calculateAmountOutMin(expectedAmountOut);

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
}
