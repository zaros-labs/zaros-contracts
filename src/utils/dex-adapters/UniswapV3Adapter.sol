// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { SwapPayload } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { ISwapRouter } from "@zaros/utils/interfaces/ISwapRouter.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";

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

    struct CollateralData {
        uint8 decimals;
        address priceAdapter;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice The pool fee
    /// @dev 500 bps (0.05%) for stable pairs with low volatility.
    /// @dev 3000 bps (0.30%) for most pairs with moderate volatility.
    /// @dev 10000 bps (1.00%) for highly volatile pairs.
    uint24 public fee;

    // the slippage tolerance
    uint256 public slippageTolerance;

    /// @notice The Mock Uniswap V3 Swap Strategy Router address
    address public mockUniswapV3SwapStrategyRouter;

    /// @notice A flag indicating if the Mock Uniswap V3 Swap Strategy Router is to be used
    bool public useMockUniswapV3SwapStrategyRouter = false;

    mapping(address collateral => CollateralData data) public collateralData;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Uniswap V3 Swap Strategy Router address
    address public constant UNISWAP_V3_SWAP_STRATEGY_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    /// @notice Uniswap V3 Swap Strategy ID
    uint128 public constant UNISWAP_V3_SWAP_STRATEGY_ID = 1;

    /*//////////////////////////////////////////////////////////////////////////
                                    INITIALIZE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, uint256 _slippageTolerance, uint24 _fee) external initializer {
        // initialize the owner
        __Ownable_init(owner);

        // set the pool fee
        setPoolFee(_fee);

        // set the slippage tolerance
        slippageTolerance = _slippageTolerance;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Executes a swap exact input with the given calldata.
    /// @param swapPayload The swap data to perform the swap.
    /// @return amountOut The amount out returned.
    function executeSwapExactInputSingle(SwapPayload calldata swapPayload) external returns (uint256 amountOut) {
        // transfer the tokenIn from the send to this contract
        IERC20(swapPayload.tokenIn).transferFrom(msg.sender, address(this), swapPayload.amountIn);

        // instantiate the swap router
        ISwapRouter swapRouter;
        if (useMockUniswapV3SwapStrategyRouter) {
            swapRouter = ISwapRouter(mockUniswapV3SwapStrategyRouter);
        } else {
            swapRouter = ISwapRouter(UNISWAP_V3_SWAP_STRATEGY_ROUTER);
        }

        // aprove the tokenIn to the swap router
        IERC20(swapPayload.tokenIn).approve(address(swapRouter), swapPayload.amountIn);

        uint256 expectedAmountOut = getExpectedOutput(swapPayload.tokenIn, swapPayload.tokenOut, swapPayload.amountIn);

        // Calculate the minimum acceptable output based on the slippage tolerance
        uint256 amountOutMinimum = calculateAmountOutMin(expectedAmountOut);

        return swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: swapPayload.tokenIn,
                tokenOut: swapPayload.tokenOut,
                fee: fee,
                recipient: swapPayload.recipient,
                deadline: swapPayload.deadline,
                amountIn: swapPayload.amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function getExpectedOutput(address tokenIn, address tokenOut, uint256 amountIn) internal view returns (uint256) { }

    function calculateAmountOutMin(uint256 amountOutMinExpected) internal view returns (uint256) {
        // calculate the amount out min
        return (amountOutMinExpected * (10_000 - slippageTolerance)) / 10_000;
    }

    /// @notice Sets pool fee
    /// @dev the minimum is 1000 (e.g. 0.1%)
    function setPoolFee(uint24 newFee) public onlyOwner {
        // revert if the new fee is not 500, 3000 or 10_000
        if (newFee != 500 && newFee != 3000 && newFee != 10_000) revert Errors.InvalidPoolFee();

        // set the new fee
        fee = newFee;

        // emit the event
        emit LogSetPoolFee(newFee);
    }

    /// @notice Sets the Mock Uniswap V3 Swap Strategy Router address
    /// @param newMockUniswapV3SwapStrategyRouter The new Mock Uniswap V3 Swap Strategy Router address
    function setMockUniswapV3SwapStrategyRouter(address newMockUniswapV3SwapStrategyRouter) external onlyOwner {
        // require that the new address is not the zero address
        mockUniswapV3SwapStrategyRouter = newMockUniswapV3SwapStrategyRouter;
    }

    /// @notice Sets the flag indicating if the Mock Uniswap V3 Swap Strategy Router is to be used
    /// @param _useMockUniswapV3SwapStrategyRouter The flag indicating if the Mock Uniswap V3 Swap Strategy Router is
    /// to be used
    function setUseMockUniswapV3SwapStrategyRouter(bool _useMockUniswapV3SwapStrategyRouter) external onlyOwner {
        useMockUniswapV3SwapStrategyRouter = _useMockUniswapV3SwapStrategyRouter;
    }

    // / @notice Sets slippage tolerance
    // / @dev the minimum is 100 (e.g. 1%)
    function setSlippageTolerance(uint256 newSlippageTolerance) external onlyOwner {
        // revert if the new slippage tolerance is less than 100
        slippageTolerance = newSlippageTolerance;

        // emit the event LogSetSlippageTolerance
        emit LogSetSlippageTolerance(newSlippageTolerance);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    UPGRADEABLE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address) internal override onlyOwner { }
}
