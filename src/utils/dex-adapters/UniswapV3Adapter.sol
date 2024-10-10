// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { SwapCallData } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { ISwapRouter } from "@zaros/utils/interfaces/ISwapRouter.sol";
import { IDexAdapter } from "@zaros/utils/interfaces/IDexAdapter.sol";

// Open zeppelin upgradeable dependencies
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

/// @notice Uniswap V3 adapter contract
contract UniswapV3Adapter is UUPSUpgradeable, OwnableUpgradeable, IDexAdapter {
    /*//////////////////////////////////////////////////////////////////////////
                                    PUBLIC VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    // the slippage tolerance
    uint256 public slippageTolerance;

    // the pool fee
    uint24 public poolFee;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Uniswap V3 Swap Strategy address
    address internal constant UNISWAP_V3_SWAP_STRATEGY_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    /// @notice Uniswap V3 Swap Strategy ID
    uint128 internal constant UNISWAP_V3_SWAP_STRATEGY_ID = 1;

    /// @notice The minimum pool fee
    uint256 internal constant MIN_POOL_FEE = 1000;

    /// @notice The minimum slippage tolerance
    uint256 internal constant MIN_SLIPPAGE_TOLERANCE = 100;

    /*//////////////////////////////////////////////////////////////////////////
                                    INITIALIZE FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(address owner, uint256 _slippageTolerance, uint24 _poolFee) external initializer {
        slippageTolerance = _slippageTolerance;
        poolFee = _poolFee;

        __Ownable_init(owner);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Executes a swap exact input with the given calldata.
    /// @param swapData The swap data to perform the swap.
    /// @return amountOut The amount out returned.
    function executeSwapExactInputSingle(SwapCallData calldata swapData) external returns (uint256 amountOut) {
        // instantiate the swap router
        ISwapRouter swapRouter = ISwapRouter(UNISWAP_V3_SWAP_STRATEGY_ROUTER);

        return swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: swapData.tokenIn,
                tokenOut: swapData.tokenOut,
                fee: poolFee,
                recipient: swapData.recipient,
                deadline: swapData.deadline,
                amountIn: swapData.amountIn,
                amountOutMinimum: swapData.amountOutMin,
                sqrtPriceLimitX96: 0
            })
        );
    }

    /// @notice Sets pool fee
    /// @dev the minimum is 1000 (e.g. 0.1%)
    function setPoolFee(uint24 newFee) external onlyOwner {
        if (newFee < MIN_POOL_FEE) revert Errors.InvalidPoolFee();
        poolFee = newFee;
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
