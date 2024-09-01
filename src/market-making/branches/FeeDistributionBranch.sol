// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;
pragma abicoder v2;

// Zaros dependencies
import { Collateral } from "../leaves/Collateral.sol";
import { FeeRecipient } from "../leaves/FeeRecipient.sol";
import { Vault } from "../leaves/Vault.sol";
import { Distribution } from "../leaves/Distribution.sol";
import { MarketMakingEngineConfiguration } from "../leaves/MarketMakingEngineConfiguration.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { ChainlinkUtil } from "@zaros/external/chainlink/ChainlinkUtil.sol";
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";

// UniSwap dependecies
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

// PRB Math dependencies SD21x18
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { IERC20, IERC20Metadata, IERC4626, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

/// @dev This contract deals with ETH to settle accumulated protocol fees, distributed to LPs and stakeholders.
contract FeeDistributionBranch {
    using SafeERC20 for IERC20;
    using FeeRecipient for FeeRecipient.Data;
    using Collateral for Collateral.Data;
    using Vault for Vault.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using Distribution for Distribution.Data;

    ISwapRouter public constant SWAP_ROUTER = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    // Uniswap pool fee at 0.3%
    uint24 public constant POOL_FEE = 3000;

    /// @notice Emit when order fee is received
    /// @param asset the address of collateral type
    /// @param amount the received fee amount
    event OrderFeeReceived(address indexed asset, uint256 amount);

    event FeesConvertedToWETH(address indexed asset, uint256 amount, uint256 totalWETH);

    event TransferCompleted(address indexed recipient, uint256 amount);

    modifier onlyPerpsEngine() {
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();
        address perpsEngine = marketMakingEngineConfiguration.perpsEngine;

        if (msg.sender != perpsEngine) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Returns the claimable amount of WETH fees for the given staker at a given vault.
    /// @param vaultId The vault id to claim fees from.
    /// @param staker The staker address.
    /// @return The amount of WETH fees claimable.
    function getEarnedFees(uint256 vaultId, address staker) external view returns (uint256) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        Distribution.Data storage distributionData = vaultData.stakingFeeDistribution;

        bytes32 actorId = bytes32(uint256(uint160(staker)));

        UD60x18 actorShares = distributionData.getActorShares(actorId);

        SD59x18 lastValuePerShare = distributionData.getLastValuePerShare(actorId);

        UD60x18 unsignedValuePerShare = ud60x18(uint256(lastValuePerShare.unwrap()));

        UD60x18 claimableAmount = unsignedValuePerShare.mul(actorShares);

        return claimableAmount.intoUint256();
    }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param asset The margin collateral address.
    /// @param amount The token amount of collateral to receive as fee.

    function receiveOrderFee(uint256 vaultId, address asset, uint256 amount) external onlyPerpsEngine {
        address assetAddress = Collateral.load(asset).asset;

        if (assetAddress == address(0)) revert Errors.UnsupportedCollateralType();

        Vault.Data storage vaultData = Vault.load(vaultId);
        Distribution.Data storage distributionData = vaultData.stakingFeeDistribution;

        // store in array if new collateral assets
        if (distributionData.feeAmounts[asset] == 0) {
            distributionData.feeAssets.push(asset);
        }

        // increment fee amount
        distributionData.feeAmounts[asset] += amount;

        // transfer fee amount
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit OrderFeeReceived(asset, amount);
    }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function convertAccumulatedFeesToWeth(uint256 vaultId) external onlyPerpsEngine {
        Vault.Data storage vaultData = Vault.load(vaultId);
        Distribution.Data storage distributionData = vaultData.stakingFeeDistribution;

        address weth = MarketMakingEngineConfiguration.load().weth;

        uint256 _accumulatedWeth;

        // Iterate over collaterals from which fees have been collected and swap
        for (uint256 i = 0; i < distributionData.feeAssets.length; i++) {
            address assets = distributionData.feeAssets[i];

            uint256 amount = distributionData.feeAmounts[distributionData.feeAssets[i]];
            distributionData.feeAmounts[distributionData.feeAssets[i]] = 0;

            // Swap collected collateral fee amount for WETH and store the obtained amount
            uint256 tokensSwapped = _swapExactTokensForWeth(assets, amount, weth);
            _accumulatedWeth += tokensSwapped;

            emit FeesConvertedToWETH(assets, amount, tokensSwapped);
        }

        delete distributionData.feeAssets;

        // Calculate and distribute shares of the converted fees
        uint256 feeDistributorShares = FeeRecipient.load(MarketMakingEngineConfiguration.load().feeDistributor).share;
        uint256 feeAmountToDistributor =
            _calculateFees(feeDistributorShares, _accumulatedWeth, Vault.TOTAL_FEE_SHARES);
        distributionData.rewardDistributorUnsettled = feeAmountToDistributor;
        distributionData.recipientsFeeUnsettled = _accumulatedWeth - distributionDatas.rewardDistributorUnsettled;
    }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function sendWethToFeeDistributor(uint256 vaultId) external onlyPerpsEngine {
        address feeDistributor = MarketMakingEngineConfiguration.load().feeDistributor;

        address wethAddr = MarketMakingEngineConfiguration.load().weth;

        Vault.Data storage vaultData = Vault.load(vaultId);
        Distribution.Data storage distributionData = vaultData.stakingFeeDistribution;

        uint256 amountToSend = distributionData.rewardDistributorUnsettled;
        distributionData.rewardDistributorUnsettled = 0;

        IERC20(wethAddr).safeTransfer(feeDistributor, amountToSend);
    }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function sendWethToFeeRecipients(uint256 vaultId, uint256 configuration) external onlyPerpsEngine {
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfigurationData =
            MarketMakingEngineConfiguration.load();

        Vault.Data storage vaultData = Vault.load(vaultId);

        /// TODO: make error for check
        // if (feeData.recipientsFeeUnsettled == 0){
        //     revert Error.;
        // }

        address[] storage recipientsList = marketMakingEngineConfigurationData.feeRecipients[configuration];
        address wethAddr = marketMakingEngineConfigurationData.weth;

        uint256 feeDistributorShares = FeeRecipient.load(marketMakingEngineConfigurationData.feeDistributor).share;
        uint256 totalShares = Vault.TOTAL_FEE_SHARES - feeDistributorShares;

        for (uint256 i; i < recipientsList.length; ++i) {
            if (recipientsList[i] == marketMakingEngineConfigurationData.feeDistributor) {
                continue; // Skip the fee distributor address
            }
            FeeRecipient.Data storage feeRecipientData = FeeRecipient.load(recipientsList[i]);
            uint256 amountToSend =
                _calculateFees(feeRecipientData.share, vaultData.recipientsFeeUnsettled, totalShares);

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
        pure
        returns (uint256 amount)
    {
        amount = (shares * accumulatedAmount) / totalShares;
    }

    function _swapExactTokensForWeth(
        address tokenIn,
        uint256 amountIn,
        address _weth
    )
        internal
        returns (uint256 amountOut)
    {
        // Approve the router to spend DAI.
        TransferHelper.safeApprove(tokenIn, address(SWAP_ROUTER), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: _weth,
            fee: POOL_FEE,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: _calculateAmountOutMinimum(tokenIn, _weth, amountIn),
            sqrtPriceLimitX96: 0
        });

        // The call to `exactInputSingle` executes the swap.
        amountOut = SWAP_ROUTER.exactInputSingle(params);
    }

    function _calculateAmountOutMinimum(
        address tokenIn,
        address tokenOut,
        uint256 amount
    )
        internal
        view
        returns (uint256 amountOutMinimum)
    {
        uint256 BPS_DENOMINATOR = 10_000;
        // this value should be in bps (e.g 1% = 100bps)
        uint256 slippage = 100;

        // Load collateral data for both input and output tokens
        Collateral.Data memory tokenInData = Collateral.load(tokenIn);
        Collateral.Data memory tokenOutCollateralData = Collateral.load(tokenOut);

        // Check if price adapters are defined
        if (tokenInData.priceAdapter == address(0) || tokenOutCollateralData.priceAdapter == address(0)) {
            revert Errors.PriceAdapterUndefined();
        }

        // Load sequencer uptime feed based on chain ID
        address sequencerUptimeFeed =
            MarketMakingEngineConfiguration.load().sequencerUptimeFeedByChainId[block.chainid];

        // Get prices for tokens
        UD60x18 tokeInUSDPrice = ChainlinkUtil.getPrice(
            IAggregatorV3(tokenInData.priceAdapter),
            tokenInData.priceFeedHeartbeatSeconds,
            IAggregatorV3(sequencerUptimeFeed)
        );
        UD60x18 tokenOutUSDPrice = ChainlinkUtil.getPrice(
            IAggregatorV3(tokenOutCollateralData.priceAdapter),
            tokenOutCollateralData.priceFeedHeartbeatSeconds,
            IAggregatorV3(sequencerUptimeFeed)
        );

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
