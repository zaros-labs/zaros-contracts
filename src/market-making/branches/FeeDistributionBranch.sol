// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;
pragma abicoder v2;

import "forge-std/console.sol";

// Zaros dependencies
import { Collateral } from "../leaves/Collateral.sol";
import { FeeRecipient } from "../leaves/FeeRecipient.sol";
import { Vault } from "../leaves/Vault.sol";
import { Distribution } from "../leaves/Distribution.sol";
import { MarketMakingEngineConfiguration } from "../leaves/MarketMakingEngineConfiguration.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketDebt } from "src/market-making/leaves/MarketDebt.sol";
import { ChainlinkUtil } from "@zaros/external/chainlink/ChainlinkUtil.sol";
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { Fee } from "src/market-making/leaves/Fee.sol";

// UniSwap dependecies
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

// PRB Math dependencies SD21x18
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { IERC20, IERC20Metadata, IERC4626, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";

/// @dev This contract deals with ETH to settle accumulated protocol fees, distributed to LPs and stakeholders.
contract FeeDistributionBranch {
    using SafeERC20 for IERC20;
    using Fee for Fee.Data;
    using Fee for Fee.Uniswap;
    using FeeRecipient for FeeRecipient.Data;
    using Collateral for Collateral.Data;
    using Vault for Vault.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using Distribution for Distribution.Data;
    using MarketDebt for MarketDebt.Data;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /// @notice Emit when order fee is received
    /// @param asset the address of collateral type
    /// @param amount the received fee amount
    event OrderFeeReceived(address indexed asset, uint256 amount);

    event FeesConvertedToWETH(address indexed asset, uint256 amount, uint256 totalWETH);

    event TransferCompleted(address indexed recipient, uint256 amount);

    modifier onlyAuthorized() {
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
    /// @return earnedFees The amount of WETH fees claimable.
    function getEarnedFees(uint128 vaultId, address staker) external view returns (uint256 earnedFees) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        bytes32 actorId = bytes32(uint256(uint160(staker)));

        UD60x18 actorShares = vaultData.stakingFeeDistribution.getActorShares(actorId);

        SD59x18 lastValuePerShare = vaultData.stakingFeeDistribution.getLastValuePerShare(actorId);

        UD60x18 unsignedValuePerShare = ud60x18(uint256(lastValuePerShare.unwrap()));

        UD60x18 claimableAmount = unsignedValuePerShare.mul(actorShares);

        earnedFees = claimableAmount.intoUint256();
    }

    /// @notice Receives collateral as a fee for processing, 
    /// this fee later will be converted to Weth and sent to beneficiaries.
    /// @dev onlyAuthorized address can call this function.
    /// @param marketId The market receiving the fees.
    /// @param asset The margin collateral address.
    /// @param amount The token amount of collateral to receive as fee.
    function receiveOrderFee(uint128 marketId, address asset, uint256 amount) external onlyAuthorized {
        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);
        if (amount == 0) revert Errors.ZeroInput("amount");

        // increment fee amount
        marketDebtData.collectedFees.receivedOrderFees.set(asset, amount);

        // transfer fee amount
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit OrderFeeReceived(asset, amount);
    }

    /// @notice Converts collected collateral amount to Weth
    /// @dev onlyAuthorized address can call this function.
    /// @param marketId The market who's fees will be converted.
    /// @param asset The asset to be swapped for wEth
    function convertAccumulatedFeesToWeth(uint128 marketId, address asset) external onlyAuthorized {
        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);

        if(marketDebtData.marketId == 0) revert Errors.UnrecognisedMarket();
        if(!marketDebtData.collectedFees.receivedOrderFees.contains(asset)) revert Errors.InvalidAsset();

        address weth = MarketMakingEngineConfiguration.load().weth;

        UD60x18 _accumulatedWeth;

        uint256 assetAmount = marketDebtData.collectedFees.receivedOrderFees.get(asset);

        if(asset == weth){

            _accumulatedWeth = _accumulatedWeth.add(ud60x18(assetAmount));  

            marketDebtData.collectedFees.receivedOrderFees.remove(asset);

            emit FeesConvertedToWETH(
                asset,
                assetAmount, 
                assetAmount
            );
        } else {
            marketDebtData.collectedFees.receivedOrderFees.remove(asset);
            // Swap collected collateral fee amount for WETH and store the obtained amount
            uint256 tokensSwapped = _swapExactTokensForWeth(asset, assetAmount, weth);
            _accumulatedWeth = _accumulatedWeth.add(ud60x18(tokensSwapped));

            emit FeesConvertedToWETH(asset, assetAmount, tokensSwapped);
        }

        // Calculate and distribute shares of the converted fees 
        uint256 marketShare = _calculateFees(
                    _accumulatedWeth, 
                    ud60x18(marketDebtData.collectedFees.marketPercentage), 
                    ud60x18(Fee.BPS_DENOMINATOR)
                );
        uint256 feeRecipientsShare = _calculateFees(
                    _accumulatedWeth, 
                    ud60x18(marketDebtData.collectedFees.feeRecipientsPercentage), 
                    ud60x18(Fee.BPS_DENOMINATOR)
                );

        marketDebtData.collectedFees.collectedFeeRecipientsFees = feeRecipientsShare;
        marketDebtData.collectedFees.collectedMarketFees = marketShare;
    }

    // /// @dev Invariants involved in the call:
    // /// TODO: add invariants
    function sendWethToVaults(uint128 marketId) external onlyAuthorized {
        // MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);
        // IERC20(wethAddr).safeTransfer(feeDistributor, amountToSend);
    }

    /// @notice Sends allocated Weth amount to fee recipients.
    /// @dev onlyAuthorized address can call this function.
    /// @param marketId The market to which fee recipients contribute.
    /// @param configuration The configuration of which fee recipients are part of.
    function sendWethToFeeRecipients(uint128 marketId, uint256 configuration) external onlyAuthorized {
    }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param vaultId The vault id to claim fees from.
    function claimFees(uint128 vaultId) external { 
    }

    function setPercentageRatio(
        uint128 marketId, 
        uint128 feeRecipientsPercentage, 
        uint128 marketPercentage
    ) 
        external 
        onlyAuthorized 
    {
        if(feeRecipientsPercentage + marketPercentage != Fee.BPS_DENOMINATOR) revert Errors.PercentageValidationFailed();

        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);

        marketDebtData.collectedFees.feeRecipientsPercentage = feeRecipientsPercentage;
        marketDebtData.collectedFees.marketPercentage = marketPercentage;
    }

    function getPercentageRatio(
        uint128 marketId
    ) 
        external 
        view 
        onlyAuthorized
        returns (uint128 feeRecipientsPercentage, uint128 marketPercentage)
    {
        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);                 
       
        return (marketDebtData.collectedFees.feeRecipientsPercentage, marketDebtData.collectedFees.marketPercentage);
    }

    function _calculateFees(
        UD60x18 shares,
        UD60x18 accumulatedAmount,
        UD60x18 totalShares
    )
        internal
        pure
        returns (uint256 amount)
    {
        UD60x18 accumulatedShareValue = shares.mul(accumulatedAmount);
        amount = accumulatedShareValue.div(totalShares).intoUint256();
    }

    function _swapExactTokensForWeth(
        address tokenIn,
        uint256 amountIn,
        address _weth
    )
        internal
        returns (uint256 amountOut)
    {
        Fee.Uniswap storage uniswapData = Fee.load_Uniswap();

        // Check if Uniswap Address is set
        if(uniswapData.swapRouter == ISwapRouter(address(0))) revert Errors.SwapRouterAddressUndefined();

        // Approve the router to spend DAI.
        TransferHelper.safeApprove(tokenIn, address(uniswapData.swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: _weth,
            fee: uniswapData.poolFee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: _calculateAmountOutMinimum(tokenIn, _weth, amountIn, uniswapData.slippage),
            sqrtPriceLimitX96: 0
        });

        // The call to `exactInputSingle` executes the swap.
        amountOut = uniswapData.swapRouter.exactInputSingle(params);
    }

    function _calculateAmountOutMinimum(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 slippage
    )
        internal
        view
        returns (uint256 amountOutMinimum)
    {   
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
        UD60x18 minAmountToReceiveInBPS = (ud60x18(Fee.BPS_DENOMINATOR).sub(ud60x18(slippage)));

        // Adjust for slippage and convert to uint256
        amountOutMinimum =
            fullAmountToReceive.mul(minAmountToReceiveInBPS).div(ud60x18(Fee.BPS_DENOMINATOR)).intoUint256();
    }
}
