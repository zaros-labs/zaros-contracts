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
import { SwapRouter } from "@zaros/market-making/leaves/SwapRouter.sol";
import { EngineAccessControl } from "@zaros/utils/EngineAccessControl.sol";
import { Fee } from "@zaros/market-making/leaves/Fee.sol";

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
    using SwapRouter for SwapRouter.Data;
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

        if (!vault.collateral.isEnabled) revert Errors.VaultDoesNotExist();

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
    /// @param swapRouterId The swap router id to be used for swapping
    function convertAccumulatedFeesToWeth(
        uint128 marketId,
        address asset,
        uint128 swapRouterId
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

        // loads the swap router data storage pointer
        SwapRouter.Data storage swapRouter = SwapRouter.load(swapRouterId);

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
            bytes memory routerCallData = abi.encodeWithSelector(
                swapRouter.selector,
                asset,
                assetAmountX18.intoUint256(),
                MarketMakingEngineConfiguration.load().weth,
                swapRouter.deadline,
                address(this)
            );

            // Swap collected collateral fee amount for WETH and store the obtained amount
            uint256 tokensSwapped = swapRouter.executeSwap(routerCallData);

            // store the amount of weth received from swap
            accumulatedWethX18 = ud60x18(tokensSwapped);
        }

        // calculate the fee amount for the market
        UD60x18 marketFeesX18 =
            Fee.calculateFees(accumulatedWethX18, ud60x18(fee.marketShare), ud60x18(SwapRouter.BPS_DENOMINATOR));

        // calculate the fee amount for the fee recipients
        UD60x18 collectedFeesX18 = Fee.calculateFees(
            accumulatedWethX18, ud60x18(fee.feeRecipientsShare), ud60x18(SwapRouter.BPS_DENOMINATOR)
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
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfigurationData =
            MarketMakingEngineConfiguration.load();

        // loads the fee data storage pointer
        Fee.Data storage fee = Fee.load(marketId);

        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);

        if (fee.collectedFees == 0) revert Errors.NoWethFeesCollected();

        address[] memory recipientsList = marketMakingEngineConfigurationData.feeRecipients[configuration];

        address weth = marketMakingEngineConfigurationData.weth;

        uint256 collectedFees = uint256(fee.collectedFees);

        uint256 totalShares;

        uint256 recepientListLength = recipientsList.length;

        // get total shares of fee recipients
        for (uint256 i; i < recepientListLength; ++i) {
            totalShares = ud60x18(totalShares).add(ud60x18(FeeRecipient.load(recipientsList[i]).share)).intoUint256();
        }

        // send amount between fee recipients
        // for (uint256 i; i < recepientListLength; ++i) {
        //     address feeRecipient = recipientsList[i];

        //     UD60x18 amountToSendX18 =
        //         Fee.calculateFees(FeeRecipient.load(feeRecipient).share, collectedFees, totalShares);

        //     fee.collectedFees = ud60x18(fee.collectedFees).sub(amountToSendX18).intoUint128();

        //     IERC20(weth).safeTransfer(feeRecipient, amountToSendX18.intoUint256());

        //     emit LogSendWethToFeeRecipients(feeRecipient, amountToSendX18.intoUint256());
        // }
    }

    /// @notice allows user to claim their share of fees
    /// @param vaultId the vault fees are claimed from
    function claimFees(uint128 vaultId) external {
        Vault.Data storage vault = Vault.load(vaultId);
        if (!vault.collateral.isEnabled) revert Errors.VaultDoesNotExist();

        bytes32 actorId = bytes32(uint256(uint160(msg.sender)));
        uint256 claimableAmount = vault.stakingFeeDistribution.getActorValueChange(actorId).intoUint256();

        if (vault.stakingFeeDistribution.actor[actorId].shares == 0) revert Errors.NoSharesAvailable();
        if (claimableAmount == 0) revert Errors.NoFeesToClaim();

        vault.stakingFeeDistribution.accumulateActor(actorId);

        SD59x18 amount = ud60x18(claimableAmount).intoSD59x18();

        vault.unsettledFeesWeth = int128(sd59x18(vault.unsettledFeesWeth).sub(amount).intoInt256());

        address weth = MarketMakingEngineConfiguration.load().weth;

        IERC20(weth).safeTransfer(msg.sender, claimableAmount);

        emit LogClaimFees(msg.sender, vaultId, claimableAmount);
    }
}
