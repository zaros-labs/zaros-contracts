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

/// @notice Uniswap V3 adapter contract
contract UniswapV3Adapter is UUPSUpgradeable, OwnableUpgradeable, IDexAdapter {
    /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    // the slippage tolerance
    uint256 public slippageTolerance;

    /// @notice The pool fee
    /// @dev 500 bps (0.05%) for stable pairs with low volatility.
    /// @dev 3000 bps (0.30%) for most pairs with moderate volatility.
    /// @dev 10000 bps (1.00%) for highly volatile pairs.
    uint24 public fee;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Uniswap V3 Swap Strategy address
    address internal constant UNISWAP_V3_SWAP_STRATEGY_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    /// @notice Uniswap V3 Swap Strategy ID
    uint128 internal constant UNISWAP_V3_SWAP_STRATEGY_ID = 1;

    /// @notice The minimum slippage tolerance
    uint256 internal constant MIN_SLIPPAGE_TOLERANCE = 100;

    /*//////////////////////////////////////////////////////////////////////////
                                    INITIALIZE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, uint256 _slippageTolerance, uint24 _fee) external initializer {
        slippageTolerance = _slippageTolerance;
        fee = _fee;

        __Ownable_init(owner);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Executes a swap exact input with the given calldata.
    /// @param swapPayload The swap data to perform the swap.
    /// @return amountOut The amount out returned.
    function executeSwapExactInputSingle(SwapPayload calldata swapPayload) external returns (uint256 amountOut) {
        // transfer the tokenIn from the send to this contract
        IERC20(swapPayload.tokenIn).transferFrom(msg.sender, address(this), swapPayload.amountIn);

        // aprove the tokenIn to the swap router
        IERC20(swapPayload.tokenIn).approve(UNISWAP_V3_SWAP_STRATEGY_ROUTER, swapPayload.amountIn);

        // instantiate the swap router
        ISwapRouter swapRouter = ISwapRouter(UNISWAP_V3_SWAP_STRATEGY_ROUTER);

        return swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: swapPayload.tokenIn,
                tokenOut: swapPayload.tokenOut,
                fee: fee,
                recipient: swapPayload.recipient,
                deadline: swapPayload.deadline,
                amountIn: swapPayload.amountIn,
                amountOutMinimum: swapPayload.amountOutMin,
                sqrtPriceLimitX96: 0
            })
        );
    }

    /// @notice Sets pool fee
    /// @dev the minimum is 1000 (e.g. 0.1%)
    function setPoolFee(uint24 newFee) external onlyOwner {
        if (newFee != 500 && newFee != 3000 && newFee != 10_000) revert Errors.InvalidPoolFee();
        fee = newFee;
    }

    // TODO: Implement slippage tolerance
    /// @notice Sets slippage tolerance
    /// @dev the minimum is 100 (e.g. 1%)
    // function setSlippageTolerance(uint256 newSlippageTolerance) external onlyOwner {
    //     if (newSlippageTolerance < MIN_SLIPPAGE_TOLERANCE) revert Errors.InvalidSlippage();
    //     slippageTolerance = newSlippageTolerance;
    // }

    /*//////////////////////////////////////////////////////////////////////////
                                    UPGRADEABLE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function _authorizeUpgrade(address) internal override onlyOwner { }
}
