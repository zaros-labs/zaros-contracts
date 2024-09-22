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
import { MarketDebt } from "src/market-making/leaves/MarketDebt.sol";
import { Fee } from "src/market-making/leaves/Fee.sol"; 
import { SwapStrategy } from "@zaros/market-making/leaves/SwapStrategy.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";

/// @dev This contract deals with ETH to settle accumulated protocol fees, distributed to LPs and stakeholders.
contract FeeDistributionBranch {
    using SafeERC20 for IERC20;
    using Fee for Fee.Data;
    using SwapStrategy for SwapStrategy.Data;
    using FeeRecipient for FeeRecipient.Data;
    using Collateral for Collateral.Data;
    using Vault for Vault.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using Distribution for Distribution.Data;
    using MarketDebt for MarketDebt.Data;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /*//////////////////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the market making engine receives collateral type for fee distribution from the perps engine.
    /// @param asset the collateral type address.
    /// @param amount the token amount of collateral type received.
    event LogReceiveOrderFee(address indexed asset, uint256 amount);

    /// @notice Emitted when received collateral type has been converted to weth.
    /// @param asset the address of collateral type to be converted.
    /// @param amount the amount of collateral type to be converted.
    /// @param totalWETH the total amounf of weth received once converted.
    event LogConvertAccumulatedFeesToWeth(address indexed asset, uint256 amount, uint256 totalWETH);

    /// @notice Emitted when end user/ fee recipient receives their weth token fees
    /// @param recipient the account address receiving the fees
    /// @param amount the token amount received by recipient
    event LogSendWethToFeeRecipients(address indexed recipient, uint256 amount);

    modifier onlyMarketMakingEngine() {
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();
        address perpsEngine = marketMakingEngineConfiguration.perpsEngine;

        if (msg.sender != perpsEngine) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    modifier onlyExistingMarket(uint128 marketId) {
        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);
        
        if(marketDebtData.marketId == 0) 
            revert Errors.UnrecognisedMarket();
        _;
    }

    /// @notice Returns the claimable amount of weth fees for the given staker at a given vault.
    /// @param vaultId The vault id to claim fees from.
    /// @param staker The staker address.
    /// @return earnedFees The amount of weth fees claimable.
    function getEarnedFees(uint128 vaultId, address staker) external view returns (uint256 earnedFees) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        bytes32 actorId = bytes32(uint256(uint160(staker)));

        UD60x18 actorShares = vaultData.stakingFeeDistribution.getActorShares(actorId);

        SD59x18 lastValuePerShare = vaultData.stakingFeeDistribution.getLastValuePerShare(actorId);

        UD60x18 unsignedValuePerShare = lastValuePerShare.intoUD60x18();

        // Calculates actor::lastValuePerShare * actor::shares
        UD60x18 claimableAmount = unsignedValuePerShare.mul(actorShares);

        earnedFees = claimableAmount.intoUint256();
    }

    /// @notice Receives collateral as a fee for processing, 
    /// this fee later will be converted to Weth and sent to beneficiaries.
    /// @dev onlyMarketMakingEngine address can call this function.
    /// @param marketId The market receiving the fees.
    /// @param asset The margin collateral address.
    /// @param amount The token amount of collateral to receive as fee.
    function receiveOrderFee(
        uint128 marketId, 
        address asset, 
        uint256 amount
    ) 
        external 
        onlyMarketMakingEngine 
        onlyExistingMarket(marketId)
    {
        if (amount == 0) revert Errors.ZeroInput("amount");

        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);
        // increment fee amount
        marketDebtData.collectedFees.receivedOrderFees.set(asset, amount);

        // loads the collateral's data storage pointer
        Collateral.Data storage collateral = Collateral.load(asset);

        // reverts if collateral isn't supported
        collateral.verifyIsEnabled();

        // transfer fee amount
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        
        emit LogReceiveOrderFee(asset, amount);
    }

    /// @notice Converts collected collateral amount to Weth
    /// @dev onlyMarketMakingEngine address can call this function.
    /// @param marketId The market who's fees will be converted.
    /// @param asset The asset to be swapped for wEth
    function convertAccumulatedFeesToWeth(
        uint128 marketId, 
        address asset
    ) 
        external 
        onlyMarketMakingEngine 
        onlyExistingMarket(marketId)
    {
        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);
        SwapStrategy.Data storage swapData = SwapStrategy.load();
        
        if(!marketDebtData.collectedFees.receivedOrderFees.contains(asset)) revert Errors.InvalidAsset();

        address weth = MarketMakingEngineConfiguration.load().weth;

        UD60x18 _accumulatedWeth;

        uint256 assetAmount = marketDebtData.collectedFees.receivedOrderFees.get(asset);

        if(asset == weth){

            _accumulatedWeth = _accumulatedWeth.add(ud60x18(assetAmount));  

            marketDebtData.collectedFees.receivedOrderFees.remove(asset);

            emit LogConvertAccumulatedFeesToWeth(
                asset,
                assetAmount, 
                assetAmount
            );
        } else {
            marketDebtData.collectedFees.receivedOrderFees.remove(asset);

            // Swap collected collateral fee amount for WETH and store the obtained amount
            uint256 tokensSwapped = SwapStrategy.swapExactTokens(swapData, asset, assetAmount, weth);
            _accumulatedWeth = _accumulatedWeth.add(ud60x18(tokensSwapped));

            emit LogConvertAccumulatedFeesToWeth(asset, assetAmount, tokensSwapped);
        }

        // Calculate and distribute shares of the converted fees 
        uint256 marketShare = Fee.calculateFees(
                    _accumulatedWeth, 
                    ud60x18(marketDebtData.collectedFees.marketPercentage), 
                    ud60x18(SwapStrategy.BPS_DENOMINATOR)
                );
        uint256 feeRecipientsShare = Fee.calculateFees(
                    _accumulatedWeth, 
                    ud60x18(marketDebtData.collectedFees.feeRecipientsPercentage), 
                    ud60x18(SwapStrategy.BPS_DENOMINATOR)
                );

        marketDebtData.collectedFees.collectedFeeRecipientsFees = feeRecipientsShare;

        marketDebtData.collectedFees.collectedMarketFees = marketShare;
       //marketDebtData.collectedFees.collectedMarketFees[marketId][asset] = marketShare;
    }

    /// @notice Sends allocated weth amount to fee recipients.
    /// @dev onlyMarketMakingEngine address can call this function.
    /// @param marketId The market to which fee recipients contribute.
    /// @param configuration The configuration of which fee recipients are part of.
    function sendWethToFeeRecipients(
        uint128 marketId, 
        uint256 configuration
    ) 
        external 
        onlyMarketMakingEngine 
        onlyExistingMarket(marketId) 
    {
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfigurationData =
            MarketMakingEngineConfiguration.load();

        MarketDebt.Data storage marketDebtData = MarketDebt.load(marketId);

        if(marketDebtData.collectedFees.collectedFeeRecipientsFees == 0) revert Errors.NoWethFeesCollected();

        address[] memory recipientsList = marketMakingEngineConfigurationData.feeRecipients[configuration];

        address wethAddr = marketMakingEngineConfigurationData.weth;

        UD60x18 collectedFees = ud60x18(marketDebtData.collectedFees.collectedFeeRecipientsFees);

        UD60x18 totalShares;

        uint256 recepientListLength = recipientsList.length;
        
        for(uint i; i < recepientListLength; ++i){
            totalShares = totalShares.add(ud60x18(FeeRecipient.load(recipientsList[i]).share));    
        }

        for(uint i; i < recepientListLength; ++i){
            address feeRecipient = recipientsList[i];

            uint256 amountToSend =
                Fee.calculateFees(ud60x18(FeeRecipient.load(feeRecipient).share), collectedFees, totalShares);

            marketDebtData.collectedFees.collectedFeeRecipientsFees = 
                ud60x18(marketDebtData.collectedFees.collectedFeeRecipientsFees).sub(ud60x18(amountToSend)).intoUint256();

            IERC20(wethAddr).safeTransfer(feeRecipient, amountToSend);

            emit LogSendWethToFeeRecipients(feeRecipient, amountToSend);
        }
    }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param vaultId The vault id to claim fees from.
    function claimFees(uint128 vaultId) external { 
    }
}
