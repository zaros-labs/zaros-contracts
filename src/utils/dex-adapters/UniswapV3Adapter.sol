// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { SwapPayload } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { ISwapRouter } from "@zaros/utils/interfaces/ISwapRouter.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { IPriceAdapter } from "@zaros/utils/interfaces/IPriceAdapter.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";

// Open zeppelin upgradeable dependencies
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice Uniswap V3 adapter contract
contract UniswapV3Adapter is UUPSUpgradeable, OwnableUpgradeable, IDexAdapter {
    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Event emitted when the pool fee is set
    /// @param newFee The new pool fee
    event LogSetPoolFee(uint24 newFee);

    /// @notice Event emitted when the slippage tolerance is set
    /// @param newSlippageTolerance The new slippage tolerance
    event LogSetSlippageTolerance(uint256 newSlippageTolerance);

    /// @notice Event emitted when the new collateral data is set
    /// @param collateral The collateral address
    /// @param decimals The collateral decimals
    /// @param priceAdapter The collateral price adapter
    event LogSetCollateralData(address indexed collateral, uint8 decimals, address priceAdapter);

    /// @notice Event emitted when the Uniswap V3 Swap Strategy Router is set
    /// @param uniswapV3SwapStrategyRouter The Uniswap V3 Swap Strategy Router address
    event LogSetUniswapV3SwapStrategyRouter(address indexed uniswapV3SwapStrategyRouter);

    /*//////////////////////////////////////////////////////////////////////////
                                    STRUCTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Collateral data struct
    /// @param decimals The collateral decimals
    /// @param priceAdapter The collateral price adapter
    struct CollateralData {
        uint8 decimals;
        address priceAdapter;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Uniswap V3 Swap Strategy Router address
    address public uniswapV3SwapStrategyRouter;

    /// @notice the slippage tolerance
    /// @dev the minimum is 100 (e.g. 1%)
    uint256 public slippageToleranceBps;

    /// @notice The collateral data
    mapping(address collateral => CollateralData data) public collateralData;

    /// @notice The pool fee
    /// @dev 500 bps (0.05%) for stable pairs with low volatility.
    /// @dev 3000 bps (0.30%) for most pairs with moderate volatility.
    /// @dev 10000 bps (1.00%) for highly volatile pairs.
    uint24 public feeBps;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Uniswap V3 Swap Strategy ID
    uint128 public constant UNISWAP_V3_SWAP_STRATEGY_ID = 1;

    /*//////////////////////////////////////////////////////////////////////////
                                    INITIALIZE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, address _uniswapV3SwapStrategyRouter, uint256 _slippageToleranceBps, uint24 _fee) external initializer {
        // initialize the owner
        __Ownable_init(owner);

        // set the Uniswap V3 Swap Strategy Router
        setUniswapV3SwapStrategyRouter(_uniswapV3SwapStrategyRouter);

        // set the pool fee
        setPoolFee(_fee);

        // set the slippage tolerance
        setSlippageTolerance(_slippageToleranceBps);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Executes a swap using the exact input amount, coming from the swap payload passed by the Market Making Engine.
    /// @param swapPayload The swap data to perform the swap.
    /// @return amountOut The amount out returned.
    function executeSwapExactInputSingle(SwapPayload calldata swapPayload) external returns (uint256 amountOut) {
        // transfer the tokenIn from the send to this contract
        IERC20(swapPayload.tokenIn).transferFrom(msg.sender, address(this), swapPayload.amountIn);

        // instantiate the swap router
        ISwapRouter swapRouter;

        // get the uniswap v3 swap strategy router
        swapRouter = ISwapRouter(uniswapV3SwapStrategyRouter);

        // aprove the tokenIn to the swap router
        IERC20(swapPayload.tokenIn).approve(address(swapRouter), swapPayload.amountIn);

        // get the expected output amount
        uint256 expectedAmountOut = getExpectedOutput(swapPayload.tokenIn, swapPayload.tokenOut, swapPayload.amountIn);

        // Calculate the minimum acceptable output based on the slippage tolerance
        uint256 amountOutMinimum = calculateAmountOutMin(expectedAmountOut);

        return swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: swapPayload.tokenIn,
                tokenOut: swapPayload.tokenOut,
                fee: feeBps,
                recipient: swapPayload.recipient,
                deadline: swapPayload.deadline,
                amountIn: swapPayload.amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            })
        );
    }

    /// @notice Get the expected output amount
    /// @param tokenIn The token in address
    /// @param tokenOut The token out address
    /// @param amountIn The amount int address
    /// @return expectedAmountOut The expected amount out
    function getExpectedOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    )
        public
        view
        returns (uint256 expectedAmountOut)
    {
        // get the price of the tokenIn
        UD60x18 priceTokenInX18 = IPriceAdapter(collateralData[tokenIn].priceAdapter).getPrice();

        // get the price of the tokenOut
        UD60x18 priceTokenOutX18 = IPriceAdapter(collateralData[tokenOut].priceAdapter).getPrice();

        // convert the amount in to UD60x18
        UD60x18 amountInX18 = Math.convertTokenAmountToUd60x18(collateralData[tokenIn].decimals, amountIn);

        // calculate the expected amount out
        expectedAmountOut = Math.convertUd60x18ToTokenAmount(
            collateralData[tokenOut].decimals, amountInX18.mul(priceTokenInX18).div(priceTokenOutX18)
        );
    }

    /// @notice Calculate the amount out min
    /// @param amountOutMinExpected The amount out min expected
    /// @return amountOutMin The amount out min
    function calculateAmountOutMin(uint256 amountOutMinExpected) public view returns (uint256 amountOutMin) {
        // calculate the amount out min
        amountOutMin = (amountOutMinExpected * (10_000 - slippageToleranceBps)) / Constants.BPS_DENOMINATOR;
    }

    /// @notice Sets pool fee
    /// @dev the minimum is 1000 (e.g. 0.1%)
    function setPoolFee(uint24 newFee) public onlyOwner {
        // revert if the new fee is not 500, 3000 or 10_000
        if (newFee != 500 && newFee != 3000 && newFee != 10_000) revert Errors.InvalidPoolFee();

        // set the new fee
        feeBps = newFee;

        // emit the event
        emit LogSetPoolFee(newFee);
    }

    /// @notice Sets slippage tolerance
    /// @dev the minimum is 100 (e.g. 1%)
    function setSlippageTolerance(uint256 newSlippageTolerance) public onlyOwner {
        // revert if the new slippage tolerance is less than 100
        slippageToleranceBps = newSlippageTolerance;

        // emit the event LogSetSlippageTolerance
        emit LogSetSlippageTolerance(newSlippageTolerance);
    }

    /// @notice Sets the collateral data
    /// @dev The collateral data is used to calculate the expected output amount
    /// @dev Only the owner can set the collateral data
    /// @param collateral The collateral address
    /// @param decimals The collateral decimals
    /// @param priceAdapter The collateral price adapter
    function setCollateralData(address collateral, uint8 decimals, address priceAdapter) public onlyOwner {
        // set the collateral data
        collateralData[collateral] = CollateralData(decimals, priceAdapter);

        // emit the event
        emit LogSetCollateralData(collateral, decimals, priceAdapter);
    }

    /// @notice Sets the Uniswap V3 Swap Strategy Router
    /// @dev Only the owner can set the Uniswap V3 Swap Strategy Router
    /// @param _uniswapV3SwapStrategyRouter The Uniswap V3 Swap Strategy Router address
    function setUniswapV3SwapStrategyRouter(address _uniswapV3SwapStrategyRouter) public onlyOwner {
        if (_uniswapV3SwapStrategyRouter == address(0)) revert Errors.ZeroInput("_uniswapV3SwapStrategyRouter");

        // set the uniswap v3 swap strategy router
        uniswapV3SwapStrategyRouter = _uniswapV3SwapStrategyRouter;

        // emit the event
        emit LogSetUniswapV3SwapStrategyRouter(_uniswapV3SwapStrategyRouter);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    UPGRADEABLE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Upgrades the contract
    /// @dev This function is called by the proxy when the contract is upgraded
    /// @dev Only the owner can upgrade the contract
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
