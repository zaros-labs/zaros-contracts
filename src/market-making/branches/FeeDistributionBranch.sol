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

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { IERC20, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { EnumerableMap } from "@openzeppelin/utils/structs/EnumerableMap.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

/// @dev This contract deals with ETH to settle accumulated protocol fees, distributed to LPs and stakeholders.
contract FeeDistributionBranch {
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

    /*//////////////////////////////////////////////////////////////////////////
                                  EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Emitted when the market making engine receives collateral type for fee distribution from the perps
    /// engine.
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

    /// @notice Emitted when a user claims their accumulated fees.
    /// @param claimer Address of the user who claimed the fees.
    /// @param vaultId Identifier of the vault from which fees were claimed.
    /// @param amount Amount of WETH claimed as fees.
    event LogClaimFees(address indexed claimer, uint128 indexed vaultId, uint256 amount);

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

        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);

        // loads the collateral's data storage pointer
        Collateral.Data storage collateral = Collateral.load(asset);

        // reverts if collateral isn't supported
        collateral.verifyIsEnabled();

        // increment fee amount
        marketDebt.collectedFees.receivedOrderFees.set(asset, amount);

        // transfer fee amount
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit LogReceiveOrderFee(asset, amount);
    }

    /// @notice Converts collected collateral amount to Weth
    /// @dev onlyMarketMakingEngine address can call this function.
    /// accumulated fees are split between market and fee recipients and then market fees are distributed to connected
    /// vaults
    /// @param marketId The market who's fees will be converted.
    /// @param asset The asset to be swapped for wEth
    function convertAccumulatedFeesToWeth(
        uint128 marketId,
        address asset,
        uint128 swapRouterId
    )
        external
        onlyMarketMakingEngine
        onlyExistingMarket(marketId)
    {
        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);
        SwapRouter.Data storage swapRouter = SwapRouter.load(swapRouterId);

        if (!marketDebt.collectedFees.receivedOrderFees.contains(asset)) revert Errors.InvalidAsset();

        uint256 _accumulatedWeth;

        uint256 assetAmount = marketDebt.collectedFees.receivedOrderFees.get(asset);

        // if asset is weth directly add to accumulated weth, else swap token for weth
        if (asset == MarketMakingEngineConfiguration.load().weth) {
            _accumulatedWeth = ud60x18(_accumulatedWeth).add(ud60x18(assetAmount)).intoUint256();

            marketDebt.collectedFees.receivedOrderFees.remove(asset);

            emit LogConvertAccumulatedFeesToWeth(asset, assetAmount, assetAmount);
        } else {
            marketDebt.collectedFees.receivedOrderFees.remove(asset);
            // Prepare the data for executing the swap
            bytes memory routerCallData = abi.encodeWithSelector(
                swapRouter.selector,
                asset,
                assetAmount,
                MarketMakingEngineConfiguration.load().weth,
                swapRouter.deadline,
                address(this)
            );
            // Swap collected collateral fee amount for WETH and store the obtained amount
            uint256 tokensSwapped = swapRouter.executeSwap(routerCallData);
            _accumulatedWeth = ud60x18(_accumulatedWeth).add(ud60x18(tokensSwapped)).intoUint256();

            emit LogConvertAccumulatedFeesToWeth(asset, assetAmount, tokensSwapped);
        }

        // Calculate and allocate shares of the converted fees
        uint128 marketShare =
            Fee.calculateFees(_accumulatedWeth, marketDebt.collectedFees.marketPercentage, SwapRouter.BPS_DENOMINATOR);
        uint128 feeRecipientsShare = Fee.calculateFees(
            _accumulatedWeth, marketDebt.collectedFees.feeRecipientsPercentage, SwapRouter.BPS_DENOMINATOR
        );

        marketDebt.collectedFees.collectedFeeRecipientsFees = feeRecipientsShare;

        // get connected vaults of market
        uint256[] memory vaultsSet = marketDebt.getConnectedVaultsIds();

        uint256 listSize = vaultsSet.length;

        uint128 totalVaultsShares;

        // calculate the total shares of vaults
        for (uint256 i; i < listSize; ++i) {
            Vault.Data storage vault = Vault.load(uint128(vaultsSet[i]));
            if (vault.collateral.asset == asset) {
                totalVaultsShares =
                    ud60x18(totalVaultsShares).add(ud60x18(vault.stakingFeeDistribution.totalShares)).intoUint128();
            }
        }

        // distribute the amount between shares and store the amount each vault has received
        for (uint256 i; i < listSize; ++i) {
            uint128 vaultShares = Fee.calculateFees(
                marketShare, Vault.load(uint128(vaultsSet[i])).stakingFeeDistribution.totalShares, totalVaultsShares
            );
            Vault.load(uint128(vaultsSet[i])).unsettledFeesWeth = int128(vaultShares);
            Vault.load(uint128(vaultsSet[i])).stakingFeeDistribution.distributeValue(
                ud60x18(vaultShares).intoSD59x18()
            );
        }
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

        MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);

        if (marketDebt.collectedFees.collectedFeeRecipientsFees == 0) revert Errors.NoWethFeesCollected();

        address[] memory recipientsList = marketMakingEngineConfigurationData.feeRecipients[configuration];

        address weth = marketMakingEngineConfigurationData.weth;

        uint256 collectedFees = uint256(marketDebt.collectedFees.collectedFeeRecipientsFees);

        uint256 totalShares;

        uint256 recepientListLength = recipientsList.length;

        // get total shares of fee recipients
        for (uint256 i; i < recepientListLength; ++i) {
            totalShares = ud60x18(totalShares).add(ud60x18(FeeRecipient.load(recipientsList[i]).share)).intoUint256();
        }

        // send amount between fee recipients
        for (uint256 i; i < recepientListLength; ++i) {
            address feeRecipient = recipientsList[i];

            uint256 amountToSend =
                Fee.calculateFees(FeeRecipient.load(feeRecipient).share, collectedFees, totalShares);

            marketDebt.collectedFees.collectedFeeRecipientsFees =
                ud60x18(marketDebt.collectedFees.collectedFeeRecipientsFees).sub(ud60x18(amountToSend)).intoUint128();

            IERC20(weth).safeTransfer(feeRecipient, amountToSend);

            emit LogSendWethToFeeRecipients(feeRecipient, amountToSend);
        }
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
