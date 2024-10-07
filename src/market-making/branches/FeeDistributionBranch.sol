// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;
pragma abicoder v2;

// Zaros dependencies
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { FeeRecipient } from "@zaros/market-making/leaves/FeeRecipient.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Distribution } from "@zaros/market-making/leaves/Distribution.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketDebt } from "src/market-making/leaves/MarketDebt.sol";
import { Fee } from "src/market-making/leaves/Fee.sol";
import { DexSwapStrategy } from "@zaros/market-making/leaves/DexSwapStrategy.sol";
import { EngineAccessControl } from "@zaros/utils/EngineAccessControl.sol";
import { Fee } from "@zaros/market-making/leaves/Fee.sol";
import { SwapCallData } from "@zaros/utils/interfaces/IDexAdapter.sol";

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
    using Fee for Fee.Data;
    using DexSwapStrategy for DexSwapStrategy.Data;
    using FeeRecipient for FeeRecipient.Data;
    using Collateral for Collateral.Data;
    using Vault for Vault.Data;
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;
    using Distribution for Distribution.Data;
    using MarketDebt for MarketDebt.Data;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using EnumerableSet for EnumerableSet.UintSet;
    using Fee for Fee.Data;

    /*//////////////////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the market making engine receives collateral type for fee distribution
    /// @param marketId The market receiving the fees
    /// @param asset The collateral type address.
    /// @param amount The token amount of collateral type received.
    event LogReceiveMarketFee(address indexed asset, uint128 marketId, uint256 amount);

    /// @notice Emitted when received collateral type has been converted to weth.
    /// @param asset The address of collateral type to be converted.
    /// @param amount The amount of collateral type to be converted.
    /// @param totalWETH The total amounf of weth received once converted.
    event LogConvertAccumulatedFeesToWeth(address indexed asset, uint256 amount, uint256 totalWETH);

    /// @notice Emitted when end user/fee recipient receives their weth token fees
    /// @param recipient The account address receiving the fees
    /// @param amount The token amount received by recipient
    event LogSendWethToFeeRecipients(address indexed recipient, uint256 amount);

    /// @notice Emitted when a user claims their accumulated fees.
    /// @param claimer Address of the user who claimed the fees.
    /// @param vaultId Identifier of the vault from which fees were claimed.
    /// @param amount Amount of WETH claimed as fees.
    event LogClaimFees(address indexed claimer, uint128 indexed vaultId, uint256 amount);

    modifier onlyExistingMarket(uint128 marketId) {
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);

        if (marketDebt.marketId == 0) {
            revert Errors.UnrecognisedMarket();
        }
        _;
    }

    /// @notice Returns the claimable amount of weth fees for the given staker at a given vault.
    /// @param vaultId The vault id to claim fees from.
    /// @param staker The staker address.
    /// @return earnedFees The amount of weth fees claimable.
    function getEarnedFees(uint128 vaultId, address staker) external view returns (uint256 earnedFees) {
        Vault.Data storage vault = Vault.load(vaultId);

        if (!vault.collateral.isEnabled) revert Errors.VaultDoesNotExist(vaultId);

        bytes32 actorId = bytes32(uint256(uint160(staker)));
        earnedFees = vault.stakingFeeDistribution.getActorValueChange(actorId).intoUint256();
    }

    /// @notice Receives collateral as a fee for processing,
    /// this fee later will be converted to Weth and sent to beneficiaries.
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

        // loads the fee data storage pointer
        Fee.Data storage fee = Fee.load(marketId);

        // loads the collateral's data storage pointer
        Collateral.Data storage collateral = Collateral.load(asset);

        // reverts if collateral isn't supported
        collateral.verifyIsEnabled();

        // convert uint256 -> UD60x18; scales input amount to 18 decimals
        UD60x18 amountX18 = collateral.convertTokenAmountToUd60x18(amount);

        // increment received fees amount
        fee.incrementReceivedMarketFees(asset, amountX18);

        // transfer fee amount
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // emit event to log the received fee
        emit LogReceiveMarketFee(asset, marketId, amount);
    }

    /// @notice Converts collected collateral amount to Weth
    /// @dev onlyRegisteredEngine address can call this function.
    /// @dev Accumulated fees are split between market and fee recipients and then market fees are distributed to
    /// connected
    /// vaults
    /// @param marketId The market who's fees will be converted.
    /// @param asset The asset to be swapped for wEth
    /// @param dexSwapStrategyId The dex swap strategy id to be used for swapping
    function convertAccumulatedFeesToWeth(
        uint128 marketId,
        address asset,
        uint128 dexSwapStrategyId
    )
        external
        onlyRegisteredEngine
        onlyExistingMarket(marketId)
    {
        // loads the fee data storage pointer
        Fee.Data storage fee = Fee.load(marketId);

        // reverts if the market hasn't received any fees for the given asset
        if (!fee.receivedMarketFees.contains(asset)) revert Errors.InvalidAsset();

        // loads the market data storage pointer
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);

        // loads the dex swap strategy data storage pointer
        DexSwapStrategy.Data storage dexSwapStrategy = DexSwapStrategy.load(dexSwapStrategyId);

        // declare variable to store accumulated weth
        UD60x18 accumulatedWethX18;

        // get the amount of asset received as fees
        UD60x18 assetAmountX18 = ud60x18(fee.receivedMarketFees.get(asset));

        // if asset is weth directly add to accumulated weth, else swap token for weth
        if (asset == MarketMakingEngineConfiguration.load().weth) {
            // store the amount of weth
            accumulatedWethX18 = assetAmountX18;
        } else {
            // prepare the data for executing the swap
            SwapCallData memory swapCallData = SwapCallData({
                tokenIn: asset,
                tokenOut: MarketMakingEngineConfiguration.load().weth,
                amountIn: assetAmountX18.intoUint256(),
                amountOutMin: 0,
                deadline: 3600,
                recipient: address(this)
            });

            // Swap collected collateral fee amount for WETH and store the obtained amount
            uint256 tokensSwapped = dexSwapStrategy.executeSwap(swapCallData);

            // store the amount of weth received from swap
            accumulatedWethX18 = ud60x18(tokensSwapped);
        }

        // calculate the fee amount for the market
        UD60x18 marketFeesX18 =
            Fee.calculateFees(accumulatedWethX18, ud60x18(fee.marketShare), ud60x18(DexSwapStrategy.BPS_DENOMINATOR));

        // calculate the fee amount for the fee recipients
        UD60x18 collectedFeesX18 = Fee.calculateFees(
            accumulatedWethX18, ud60x18(fee.feeRecipientsShare), ud60x18(DexSwapStrategy.BPS_DENOMINATOR)
        );

        // increment the collected fees
        fee.incrementCollectedFees(collectedFeesX18);

        // get connected vaults of market
        uint256[] memory vaultsSet = marketDebt.getConnectedVaultsIds();

        // store the length of the vaults set
        uint256 listSize = vaultsSet.length;

        // variable to store the total shares of vaults
        UD60x18 totalVaultsSharesX18;

        // calculate the total shares of vaults
        for (uint256 i; i < listSize; ++i) {
            // load the vault data storage pointer
            Vault.Data storage vault = Vault.load(uint128(vaultsSet[i]));

            // add the total shares of the vault to the total shares of vaults
            totalVaultsSharesX18 = totalVaultsSharesX18.add(ud60x18(vault.stakingFeeDistribution.totalShares));
        }

        // distribute the amount between shares and store the amount each vault has received
        for (uint256 i; i < listSize; ++i) {
            // load the vault data storage pointer
            Vault.Data storage vault = Vault.load(uint128(vaultsSet[i]));

            // calculate the amount of weth each vault has received
            SD59x18 vaultFeeAmountX18 = Fee.calculateFees(
                marketFeesX18, ud60x18(vault.stakingFeeDistribution.totalShares), totalVaultsSharesX18
            ).intoSD59x18();

            // update the unsettled fees of the vault
            vault.updateUnsettledFeesWeth(vaultFeeAmountX18);

            // distribute the amount between the vault's shares
            vault.stakingFeeDistribution.distributeValue(vaultFeeAmountX18);
        }

        // remove the asset from the received market fees
        fee.receivedMarketFees.remove(asset);

        // emit event to log the conversion of fees to weth
        emit LogConvertAccumulatedFeesToWeth(asset, assetAmountX18.intoUint256(), accumulatedWethX18.intoUint256());
    }

    /// @notice Sends allocated weth amount to fee recipients.
    /// @dev onlyRegisteredEngine address can call this function.
    /// @param marketId The market to which fee recipients contribute.
    /// @param configuration The configuration of which fee recipients are part of.
    function sendWethToFeeRecipients(
        uint128 marketId,
        uint256 configuration
    )
        external
        onlyRegisteredEngine
        onlyExistingMarket(marketId)
    {
        // loads the fee data storage pointer
        Fee.Data storage fee = Fee.load(marketId);

        // reverts if no fees have been collected
        if (fee.collectedFees == 0) revert Errors.NoWethFeesCollected();

        // loads the market making engine configuration data storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfigurationData =
            MarketMakingEngineConfiguration.load();

        // get the fee recipients list
        address[] memory recipientsList = marketMakingEngineConfigurationData.feeRecipientsAddress[configuration];

        // store the length of the fee recipients list
        uint256 recepientListLength = recipientsList.length;

        // weth address
        address weth = marketMakingEngineConfigurationData.weth;

        // convert collected fees to UD60x18
        UD60x18 collectedFeesX18 = ud60x18(fee.collectedFees);

        // variable to store the total shares of fee recipients
        UD60x18 totalSharesX18;

        // load the weth collateral data storage pointer
        Collateral.Data storage wethCollateral = Collateral.load(weth);

        // get total shares of fee recipients
        for (uint256 i; i < recepientListLength; ++i) {
            totalSharesX18 = totalSharesX18.add(ud60x18(FeeRecipient.load(recipientsList[i]).share));
        }

        // send amount between fee recipients
        for (uint256 i; i < recepientListLength; ++i) {
            // the current fee recipient
            address feeRecipient = recipientsList[i];

            // calculate the amount to send to the fee recipient
            UD60x18 amountToSendX18 =
                Fee.calculateFees(collectedFeesX18, ud60x18(FeeRecipient.load(feeRecipient).share), totalSharesX18);

            // decrement the collected fees
            fee.decrementCollectedFees(amountToSendX18);

            // convert the amountToSendX18 to weth amount
            uint256 amountToSend = wethCollateral.convertUd60x18ToTokenAmount(amountToSendX18);

            // send the amount to the fee recipient
            IERC20(weth).safeTransfer(feeRecipient, amountToSend);

            // emit event to log the amount sent to the fee recipient
            emit LogSendWethToFeeRecipients(feeRecipient, amountToSend);
        }
    }

    /// @notice allows user to claim their share of fees
    /// @param vaultId the vault fees are claimed from
    function claimFees(uint128 vaultId) external {
        // load the vault data storage pointer
        Vault.Data storage vault = Vault.load(vaultId);

        // reverts if the vault doesn't exist
        if (!vault.collateral.isEnabled) revert Errors.VaultDoesNotExist(vaultId);

        // get the actor id
        bytes32 actorId = bytes32(uint256(uint160(msg.sender)));

        // reverts if the actor has no shares
        if (vault.stakingFeeDistribution.actor[actorId].shares == 0) revert Errors.NoSharesAvailable();

        // get the claimable amount of fees
        UD60x18 amountToClaimX18 = vault.stakingFeeDistribution.getActorValueChange(actorId).intoUD60x18();

        // reverts if the claimable amount is 0
        if (amountToClaimX18.isZero()) revert Errors.NoFeesToClaim();

        vault.stakingFeeDistribution.accumulateActor(actorId);

        // update the unsettled fees of the vault
        vault.updateUnsettledFeesWeth(-amountToClaimX18.intoSD59x18());

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
