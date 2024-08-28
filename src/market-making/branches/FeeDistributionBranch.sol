// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;
pragma abicoder v2;

// Zaros dependencies
import { Fee } from "../leaves/Fee.sol";
import { Collateral } from "../leaves/Collateral.sol";
import { FeeRecipient } from "../leaves/FeeRecipient.sol";
import { Vault } from "../leaves/Vault.sol";
import { MarketMakingEngineConfiguration } from "../leaves/MarketMakingEngineConfiguration.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// UniSwap dependecies
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";

// Open Zeppelin dependencies
import { IERC20, IERC4626, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

/// @dev This contract deals with ETH to settle accumulated protocol fees, distributed to LPs and stakeholders.
contract FeeDistributionBranch {
    using SafeERC20 for IERC20;
    using Fee for Fee.Data;
    using FeeRecipient for FeeRecipient.Data;
    using Collateral for Collateral.Data;
    using Vault for Vault.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;

    modifier onlyAuthorized {
        if(msg.sender != MarketMakingEngineConfiguration.load().perpsEngine){
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    ISwapRouter public constant SWAP_ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    // For this example, we will set the pool fee to 0.3%.
    uint24 public constant POOL_FEE = 3000;

    /// @notice Emit when order fee is received
    /// @param collateral the address of collateral type
    /// @param amount the received fee amount
    event OrderFeeReceived(address indexed collateral, uint256 amount);

    event FeesConvertedToWETH(address indexed collateral, uint256 amount, uint256 totalWETH);

    event TransferCompleted(address indexed recipient, uint256 amount);

    /// @notice Returns the claimable amount of WETH fees for the given staker at a given vault.
    /// @param vaultId The vault id to claim fees from.
    /// @param staker The staker address.
    /// @return The amount of WETH fees claimable.
    function getEarnedFees(uint128 vaultId, address staker) external view returns (uint256) { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param collateral The margin collateral address.
    /// @param amount The token amount of collateral to receive as fee.

    function receiveOrderFee(address collateral, uint256 amount) external onlyAuthorized {
        // fetch collateral asset address
        address collateralAssetAddress = Collateral.load(collateral).asset;

        // revert if collateral asset not supported
        if (collateralAssetAddress == address(0)) revert Errors.UnsupportedCollateralType();
    

        if (IERC20(collateral).balanceOf(msg.sender) < amount) revert Errors.NotEnoughCollateralBalance(IERC20(collateral).balanceOf(msg.sender));

        // fetch storage slot for fee data
        Fee.Data storage fee = Fee.load();

        // store in array if new collateral
        if (fee.feeAmounts[collateral] == 0) {
            fee.orderFeeCollaterals.push(collateral);
        }

        // increment fee amount
        fee.feeAmounts[collateral] += amount;

        // transfer fee amount
        IERC20(collateral).safeTransferFrom(msg.sender, address(this), amount);

        emit OrderFeeReceived(collateral, amount);
    }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function convertAccumulatedFeesToWeth() external onlyAuthorized {
        // fetch storage slot for fee data
        Fee.Data storage feeData = Fee.load();

        uint256 _accumulatedWeth;

        // Iterate over collaterals from which fees have been collected
        for (uint256 i = 0; i < feeData.orderFeeCollaterals.length; i++) {
            // Retrieve collateral address
            address collateral = feeData.orderFeeCollaterals[i];

            // Fetch and reset the collected fee amount for the collateral
            uint256 amount = feeData.feeAmounts[feeData.orderFeeCollaterals[i]];
            feeData.feeAmounts[feeData.orderFeeCollaterals[i]] = 0;

            // Swap collected collateral fee amount for WETH and store the obtained amount
            _accumulatedWeth += _swapCollateralForWeth(collateral, amount);

            // Emit an event for each conversion
            emit FeesConvertedToWETH(collateral, amount, _swapCollateralForWeth(collateral, amount));
        }

        // Clear the list of fee collaterals after processing
        delete feeData.orderFeeCollaterals;

        // Calculate and distribute shares of the converted fees
        uint256 feeDistributorShares = FeeRecipient.load(MarketMakingEngineConfiguration.load().feeDistributor).share;
        uint256 feeAmountToDistributor = _calculateFees(feeDistributorShares, _accumulatedWeth, Fee.TOTAL_FEE_SHARES);
        feeData.feeDistributorUnsettled = feeAmountToDistributor;
        feeData.recipientsFeeUnsettled = _accumulatedWeth - feeData.feeDistributorUnsettled;
    }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function sendWethToFeeDistributor() external onlyAuthorized {

        address feeDistributor = MarketMakingEngineConfiguration.load().feeDistributor;

        address wethAddr = MarketMakingEngineConfiguration.load().weth;

        Fee.Data storage feeData = Fee.load();
        uint256 amountToSend = feeData.feeDistributorUnsettled;
        feeData.feeDistributorUnsettled = 0;
        // send fee amount to feeDistributor
        IERC20(wethAddr).safeTransfer(feeDistributor, amountToSend);
    }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function sendWethToFeeRecipients(uint256 configuration) external onlyAuthorized {
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfigurationData =
            MarketMakingEngineConfiguration.load();

        Fee.Data storage feeData = Fee.load();

        /// TODO: make error for check
        // if (feeData.recipientsFeeUnsettled == 0){
        //     revert Error.;
        // }

        address[] storage recipientsList = marketMakingEngineConfigurationData.feeRecipients[configuration];
        address wethAddr = marketMakingEngineConfigurationData.weth;

        uint256 feeDistributorShares = FeeRecipient.load(marketMakingEngineConfigurationData.feeDistributor).share;
        uint256 totalShares = Fee.TOTAL_FEE_SHARES - feeDistributorShares;
        
        for (uint256 i; i < recipientsList.length; ++i) {
            if (recipientsList[i] == marketMakingEngineConfigurationData.feeDistributor) {
            continue; // Skip the fee distributor address
        }
            FeeRecipient.Data storage feeRecipientData = FeeRecipient.load(recipientsList[i]);
            uint256 amountToSend = _calculateFees(feeRecipientData.share, feeData.recipientsFeeUnsettled, totalShares);

            address recipientAddress = recipientsList[i];

            IERC20(wethAddr).safeTransfer(recipientAddress, amountToSend);

            emit TransferCompleted(recipientsList[i], amountToSend);
        }
    }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param vaultId The vault id to claim fees from.
    function claimFees(uint128 vaultId) external { }

    function _calculateFees(
        uint256 shares,
        uint256 accumulatedAmount,
        uint256 totalShares
    )
        internal
        view
        returns (uint256 amount)
    {
        amount = (shares * accumulatedAmount) / totalShares;
    }

    function _swapCollateralForWeth(address tokenIn, uint256 amountIn) internal returns (uint256 amountOut) {

        address weth = MarketMakingEngineConfiguration.load().weth;
        
        // Approve the router to spend DAI.
        TransferHelper.safeApprove(tokenIn, address(SWAP_ROUTER), amountIn);

        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: weth,
                fee: POOL_FEE,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                /// TODO: Oracle
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        amountOut = SWAP_ROUTER.exactInputSingle(params);
    }
}
