// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Distribution } from "@zaros/market-making/leaves/Distribution.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Market } from "src/market-making/leaves/Market.sol";
import { DexSwapStrategy } from "@zaros/market-making/leaves/DexSwapStrategy.sol";
import { EngineAccessControl } from "@zaros/utils/EngineAccessControl.sol";
import { SwapPayload } from "@zaros/utils/interfaces/IDexAdapter.sol";
import { Constants } from "@zaros/utils/Constants.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

/// @dev This contract deals with ETH to settle accumulated protocol fees, distributed to LPs and stakeholders.
contract FeeDistributionBranch is EngineAccessControl {
    using SafeERC20 for IERC20;
    using DexSwapStrategy for DexSwapStrategy.Data;
    using Collateral for Collateral.Data;
    using Vault for Vault.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using Distribution for Distribution.Data;
    using Market for Market.Data;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    /*//////////////////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the market making engine receives collateral type for fee distribution
    /// @param marketId The market receiving the fees
    /// @param asset The collateral type address.
    /// @param amount The token amount of collateral type received.
    event LogReceiveMarketFee(address indexed asset, uint128 marketId, uint256 amount);

    /// @notice Emitted when received collateral type has been converted to weth.
    /// @param totalWethX18 The total amounf of weth received once converted.
    event LogConvertAccumulatedFeesToWeth(uint256 totalWethX18);

    /// @notice Emitted when end user/fee recipient receives their weth token fees
    /// @param recipient The account address receiving the fees
    /// @param amount The token amount received by recipient
    event LogSendWethToFeeRecipients(address indexed recipient, uint256 amount);

    /// @notice Emitted when a user claims their accumulated fees.
    /// @param claimer Address of the user who claimed the fees.
    /// @param vaultId Identifier of the vault from which fees were claimed.
    /// @param amount Amount of WETH claimed as fees.
    event LogClaimFees(address indexed claimer, uint128 indexed vaultId, uint256 amount);

    /// @notice Returns the claimable amount of weth fees for the given staker at a given vault.
    /// @param vaultId The vault id to claim fees from.
    /// @param staker The staker address.
    /// @return earnedFees The amount of weth fees claimable.
    function getEarnedFees(uint128 vaultId, address staker) external view returns (uint256 earnedFees) {
        Vault.Data storage vault = Vault.load(vaultId);

        bytes32 actorId = bytes32(uint256(uint160(staker)));

        earnedFees = vault.wethRewardDistribution.getActorValueChange(actorId).intoUint256();
    }

    /// @notice Receives collateral as a fee for processing,
    /// this fee later will be converted to WETH and sent to beneficiaries.
    /// @dev onlyRegisteredEngine address can call this function.
    /// @param marketId The market receiving the fees.
    /// @param asset The margin collateral address.
    /// @param amount The token amount of collateral to receive as fee.
    function receiveMarketFee(
        uint128 marketId,
        address asset,
        uint256 amount
    )
        external
        onlyRegisteredEngine
        onlyExistingMarket(marketId)
    {
        // verify input amount
        if (amount == 0) revert Errors.ZeroInput("amount");

        // loads the market data storage pointer
        Market.Data storage market = Market.load(marketId);

        // loads the collateral's data storage pointer
        Collateral.Data storage collateral = Collateral.load(asset);

        // reverts if collateral isn't supported
        collateral.verifyIsEnabled();

        // convert uint256 -> UD60x18; scales input amount to 18 decimals
        UD60x18 amountX18 = collateral.convertTokenAmountToUd60x18(amount);

        // increment received fees amount
        market.incrementReceivedMarketFees(asset, amountX18);

        // transfer fee amount
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // emit event to log the received fee
        emit LogReceiveMarketFee(asset, marketId, amount);
    }

    /// @notice Converts collected collateral amount to WETH
    /// @dev Only registered engines can call this function.
    /// @dev Net WETH rewards are split among fee recipients and vaults delegating credit to the market, according to
    /// the configured share values.
    /// @param marketId The id of the market to have its fees converted to WETH.
    /// @param asset The asset to be swapped for WETH.
    /// @param dexSwapStrategyId The dex swap strategy id to be used for swapping.
    function convertAccumulatedFeesToWeth(
        uint128 marketId,
        address asset,
        uint128 dexSwapStrategyId
    )
        external
        onlyRegisteredSystemKeepers
        onlyExistingMarket(marketId)
    {
        // loads the collateral data storage pointer
        Collateral.Data storage collateral = Collateral.load(asset);

        // reverts if the collateral isn't enabled
        collateral.verifyIsEnabled();

        // loads the market data storage pointer
        Market.Data storage market = Market.load(marketId);

        // reverts if the market hasn't received any fees for the given asset
        if (!market.receivedMarketFees.contains(asset)) revert Errors.MarketDoesNotContainTheAsset(asset);

        // get the amount of asset received as fees
        UD60x18 assetAmountX18 = ud60x18(market.receivedMarketFees.get(asset));

        // reverts if the amount is zero
        if (assetAmountX18.isZero()) revert Errors.AssetAmountIsZero(asset);

        // convert the asset amount to token amount
        uint256 assetAmount = collateral.convertUd60x18ToTokenAmount(assetAmountX18);

        // declare variable to store accumulated weth
        UD60x18 receivedWethX18;

        // weth address
        address weth = MarketMakingEngineConfiguration.load().weth;

        // if asset is weth directly add to accumulated weth, else swap token for weth
        if (asset == weth) {
            // store the amount of weth
            receivedWethX18 = assetAmountX18;
        } else {
            // loads the dex swap strategy data storage pointer
            DexSwapStrategy.Data storage dexSwapStrategy = DexSwapStrategy.load(dexSwapStrategyId);

            // reverts if the dex swap strategy has an invalid dex adapter
            if (dexSwapStrategy.dexAdapter == address(0)) {
                revert Errors.DexSwapStrategyHasAnInvalidDexAdapter(dexSwapStrategyId);
            }

            // load the weth collateral data storage pointer
            Collateral.Data storage wethCollateral = Collateral.load(weth);

            // approve the collateral token to the dex adapter
            IERC20(asset).approve(dexSwapStrategy.dexAdapter, assetAmount);

            // prepare the data for executing the swap
            SwapPayload memory swapCallData =
                SwapPayload({ tokenIn: asset, tokenOut: weth, amountIn: assetAmount, recipient: address(this) });

            // Swap collected collateral fee amount for WETH and store the obtained amount
            uint256 tokensSwapped = dexSwapStrategy.executeSwapExactInputSingle(swapCallData);
            UD60x18 tokensSwappedX18 = wethCollateral.convertTokenAmountToUd60x18(tokensSwapped);

            // store the amount of weth received from swap
            receivedWethX18 = tokensSwappedX18;
        }

        // get the total fee recipients shares
        UD60x18 feeRecipientsSharesX18 = MarketMakingEngineConfiguration.load().getTotalFeeRecipientsShares();

        // calculate the weth rewards for protocol and vaults
        UD60x18 receivedProtocolWethRewardX18 = receivedWethX18.mul(feeRecipientsSharesX18);
        UD60x18 receivedVaultsWethRewardX18 =
            receivedWethX18.mul(ud60x18(Constants.MAX_SHARES).sub(feeRecipientsSharesX18));

        // adds the weth received for protocol and vaults rewards using the assets previously paid by the engine as
        // fees, and remove its balance from the market's `receivedMarketFees` map
        market.receiveWethReward(asset, receivedProtocolWethRewardX18, receivedVaultsWethRewardX18);

        // emit event to log the conversion of fees to weth
        emit LogConvertAccumulatedFeesToWeth(receivedWethX18.intoUint256());
    }

    /// @notice Sends allocated weth amount to fee recipients.
    /// @dev onlyRegisteredEngine address can call this function.
    /// @param marketId The market to which fee recipients contribute.
    function sendWethToFeeRecipients(uint128 marketId) external onlyRegisteredEngine onlyExistingMarket(marketId) {
        // loads the fee data storage pointer
        Market.Data storage market = Market.load(marketId);

        // reverts if no protocol weth rewards have been collected
        if (market.pendingProtocolWethReward == 0) revert Errors.NoWethFeesCollected();

        // loads the market making engine configuration data storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfigurationData =
            MarketMakingEngineConfiguration.load();

        // loads the protocol fee recipients storage pointer
        EnumerableMap.AddressToUintMap storage protocolFeeRecipients =
            marketMakingEngineConfigurationData.protocolFeeRecipients;

        // store the length of the fee recipients list
        uint256 recipientListLength = protocolFeeRecipients.length();

        // weth address
        address weth = marketMakingEngineConfigurationData.weth;

        // convert collected fees to UD60x18
        UD60x18 pendingProtocolWethRewardX18 = ud60x18(market.pendingProtocolWethReward);

        // variable to store the total shares of fee recipients
        UD60x18 totalSharesX18;

        // load the weth collateral data storage pointer
        Collateral.Data storage wethCollateral = Collateral.load(weth);

        // store the recipients and shares in cache
        address[] memory cacheRecipientsList = new address[](recipientListLength);
        uint256[] memory cacheSharesList = new uint256[](recipientListLength);

        // get total shares of fee recipients
        for (uint256 i; i < recipientListLength; ++i) {
            // get the recipient and shares
            (cacheRecipientsList[i], cacheSharesList[i]) = protocolFeeRecipients.at(i);

            // add the shares to the total shares
            totalSharesX18 = totalSharesX18.add(ud60x18(cacheSharesList[i]));
        }

        if (totalSharesX18.isZero()) {
            // if total shares is zero, revert
            revert Errors.NoSharesAvailable();
        }

        // send amount between fee recipients
        for (uint256 i; i < recipientListLength; ++i) {
            // calculate the amount to send to the fee recipient
            UD60x18 amountToSendX18 = pendingProtocolWethRewardX18.mul(ud60x18(cacheSharesList[i]));

            if (amountToSendX18.isZero()) {
                // if the amount to send is zero, continue
                continue;
            }

            // subtract the protocol weth reward being sent
            market.pendingProtocolWethReward -= amountToSendX18.intoUint128();

            // convert the amountToSendX18 to weth amount
            uint256 amountToSend = wethCollateral.convertUd60x18ToTokenAmount(amountToSendX18);

            // send the amount to the fee recipient
            IERC20(weth).safeTransfer(cacheRecipientsList[i], amountToSend);

            // emit event to log the amount sent to the fee recipient
            emit LogSendWethToFeeRecipients(cacheRecipientsList[i], amountToSend);
        }
    }

    /// @notice allows user to claim their share of fees
    /// @param vaultId the vault fees are claimed from
    function claimFees(uint128 vaultId) external {
        // load the vault data storage pointer
        Vault.Data storage vault = Vault.load(vaultId);

        // get the actor id
        bytes32 actorId = bytes32(uint256(uint160(msg.sender)));

        // reverts if the actor has no shares
        if (vault.wethRewardDistribution.actor[actorId].shares == 0) revert Errors.NoSharesAvailable();

        // get the claimable amount of fees
        UD60x18 amountToClaimX18 = vault.wethRewardDistribution.getActorValueChange(actorId).intoUD60x18();

        // reverts if the claimable amount is 0
        if (amountToClaimX18.isZero()) revert Errors.NoFeesToClaim();

        vault.wethRewardDistribution.accumulateActor(actorId);

        // weth address
        address weth = MarketMakingEngineConfiguration.load().weth;

        // load the weth collateral data storage pointer
        Collateral.Data storage wethCollateral = Collateral.load(weth);

        // convert the amount to claim to weth amount
        uint256 amountToClaim = wethCollateral.convertUd60x18ToTokenAmount(amountToClaimX18);

        // transfer the amount to the claimer
        IERC20(weth).safeTransfer(msg.sender, amountToClaim);

        // emit event to log the amount claimed
        emit LogClaimFees(msg.sender, vaultId, amountToClaim);
    }
}
