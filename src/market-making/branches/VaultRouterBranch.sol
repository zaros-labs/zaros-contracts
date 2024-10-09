// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { WithdrawalRequest } from "@zaros/market-making/leaves/WithdrawalRequest.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Distribution } from "@zaros/market-making/leaves/Distribution.sol";
import { Referral } from "@zaros/market-making/leaves/Referral.sol";
import { CustomReferralConfiguration } from "@zaros/utils/leaves/CustomReferralConfiguration.sol";

// Open Zeppelin dependencies
import { IERC20, IERC4626, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

// TODO: think about referrals
contract VaultRouterBranch {
    using SafeERC20 for IERC20;
    using Distribution for Distribution.Data;
    using Referral for Referral.Data;
    using Collateral for Collateral.Data;
    using SafeCast for uint256;
    using Math for uint256;

    /// @notice Emitted when a user stakes shares.
    /// @param vaultId The ID of the vault which shares are staked.
    /// @param user The address of the user who staked the shares.
    /// @param shares The amount of shares staked by the user.
    event LogStake(uint256 indexed vaultId, address indexed user, uint256 shares);

    /// @notice Emitted when a user initiates a withdrawal from a vault.
    /// @param vaultId The ID of the vault from which the shares are being withdrawn.
    /// @param user The address of the user who initiated the withdrawal.
    /// @param shares The amount of shares to be withdrawn by the user.
    event LogInitiateWithdrawal(uint256 indexed vaultId, address indexed user, uint128 shares);

    /// @notice Emitted when a user unstakes shares.
    /// @param vaultId The ID of the vault which shares are unstaked.
    /// @param user The address of the user who unstaked the shares.
    /// @param shares The amount of shares unstaked by the user.
    event LogUnstake(uint256 indexed vaultId, address indexed user, uint256 shares);

    /// @notice Emitted when a referral code is set.
    /// @param stakingUser The user address that stakes.
    /// @param referrer The referrer address.
    /// @param referralCode The referral code.
    /// @param isCustomReferralCode A boolean indicating if the referral code is custom.
    event LogReferralSet(
        address indexed stakingUser, address indexed referrer, bytes referralCode, bool isCustomReferralCode
    );

    /// @notice Emitted when a user deposist assets.
    /// @param vaultId The ID of the vault which assets are deposited.
    /// @param user The user that deposits the assets.
    /// @param assets The assets amount.
    event LogDeposit(uint256 indexed vaultId, address indexed user, uint256 assets);

    /// @notice Emitted when a user deposist assets.
    /// @param vaultId The ID of the vault which assets are deposited.
    /// @param user The user that deposits the assets.
    /// @param shares The shares amount being redeemed.
    event LogRedeem(uint256 indexed vaultId, address indexed user, uint256 shares);

    /// @notice Returns the data and state of a given vault.
    /// @param vaultId The vault identifier.
    /// @return totalDeposited The total amount of collateral assets deposited in the vault.
    /// @return depositCap The maximum amount of collateral assets that can be deposited in the vault.
    /// @return withdrawalDelay The delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @return unsettledRealizedDebtUsd The total amount of unsettled debt in USD.
    /// @return settledRealizedDebtUsd The total amount of settled debt in USD.
    /// @return indexToken The index token address.
    /// @return collateral The collateral asset data.
    function getVaultData(uint128 vaultId)
        external
        view
        returns (
            uint128 totalDeposited,
            uint128 depositCap,
            uint128 withdrawalDelay,
            int128 unsettledRealizedDebtUsd,
            int128 settledRealizedDebtUsd,
            address indexToken,
            Collateral.Data memory collateral
        )
    {
        // load vault by id
        Vault.Data storage vault = Vault.load(vaultId);

        totalDeposited = vault.totalDeposited;
        depositCap = vault.depositCap;
        withdrawalDelay = vault.withdrawalDelay;
        unsettledRealizedDebtUsd = vault.unsettledRealizedDebtUsd;
        settledRealizedDebtUsd = vault.settledRealizedDebtUsd;
        indexToken = vault.indexToken;
        collateral = vault.collateral;
    }

    // TODO: update the debt distribution chain of the Vault and its connected markets in order to retrieve the latest
    // values

    /// @notice Returns the swap rate from index token to collateral asset for the provided vault.
    /// @param vaultId The vault identifier.
    /// @param sharesIn The amount of input shares for which to calculate the swap rate.
    /// @return assetsOut The swap price from index token to collateral asset.
    function getIndexTokenSwapRate(uint128 vaultId, uint256 sharesIn) external view returns (UD60x18 assetsOut) {
        // fetch storage slot for vault by id
        Vault.Data storage vault = Vault.load(vaultId);

        // get the total assets
        SD59x18 totalAssetsX18 = sd59x18(IERC4626(vault.indexToken).totalAssets().toInt256());

        // convert total debt to 18 dec
        SD59x18 unsettledDebtX18 = sd59x18(vault.unsettledRealizedDebtUsd); // TODO which debt do we take here

        // get decimal offset
        uint8 decimalOffset = 18 - IERC20Metadata(vault.indexToken).decimals();

        // get collateral asset price
        UD60x18 assetPriceX18 = vault.collateral.getPrice();

        // get amount of assets that are credited
        SD59x18 assetsCreditX18 = unsettledDebtX18.div(assetPriceX18.intoSD59x18());

        // calculate the total assets minus the debt
        SD59x18 totalAssetsMinusDebtX18 = totalAssetsX18.add(sd59x18(1)).sub(assetsCreditX18);

        // sd59x18 -> uint256
        uint256 totalAssetsMinusDebt = totalAssetsMinusDebtX18.intoUint256();

        // Get the asset amount out for the input amount of shares, taking into account the unsettled debt
        // See {IERC4626-previewRedeem}
        uint256 previewAssetsOut = sharesIn.mulDiv(
            totalAssetsMinusDebt,
            IERC4626(vault.indexToken).totalSupply() + 10 ** decimalOffset,
            Math.Rounding.Floor
        );

        // Return the final adjusted amountOut as UD60x18
        return ud60x18(previewAssetsOut);
    }

    /// @notice Returns the swap rate from collateral asset to index token for the provided vault.
    /// @param vaultId The vault identifier.
    /// @param assetsIn The amount of input assets for which to calculate the swap rate.
    /// @return sharesOut The swap price from underlying collateral asset to the vault shares.
    function getVaultAssetSwapRate(uint128 vaultId, uint256 assetsIn) external view returns (UD60x18 sharesOut) {
        // fetch storage slot for vault by id
        Vault.Data storage vault = Vault.load(vaultId);

        // get the total assets
        SD59x18 totalAssetsX18 = sd59x18(IERC4626(vault.indexToken).totalAssets().toInt256());

        // convert total debt to 18 dec
        SD59x18 unsettledDebtX18 = sd59x18(vault.unsettledRealizedDebtUsd); // TODO which debt do we take here. Do we take settled debt as well ?

        // get decimal offset
        uint8 decimalOffset = 18 - IERC20Metadata(vault.indexToken).decimals();

        // get collateral asset price
        UD60x18 assetPriceX18 = vault.collateral.getPrice();

        // get amount of assets that are credited
        SD59x18 assetsCreditX18 = unsettledDebtX18.div(assetPriceX18.intoSD59x18());

        // calculate the total assets minus the debt
        SD59x18 totalAssetsMinusDebtX18 = totalAssetsX18.add(sd59x18(1)).sub(assetsCreditX18);

        // sd59x18 -> uint256
        uint256 totalAssetsMinusDebt = totalAssetsMinusDebtX18.intoUint256();

        // Get the shares amount out for the input amount of tokens, taking into account the unsettled debt
        // See {IERC4626-previewDeposit}.
        uint256 previewSharesOut = assetsIn.mulDiv(
            IERC4626(vault.indexToken).totalSupply() + 10 ** decimalOffset,
            totalAssetsMinusDebt,
            Math.Rounding.Floor
        );

        // Return the final adjusted amountOut as UD60x18
        return ud60x18(previewSharesOut);
    }

    /// @notice Deposits a given amount of collateral assets into the provided vault in exchange for index tokens.
    /// @dev Invariants involved in the call:
    /// The total deposits MUST not exceed the vault after the deposit.
    /// The number of received shares MUST be greater than or equal to minShares.
    /// @param vaultId The vault identifier.
    /// @param assets The amount of collateral to deposit, in the underlying ERC20 decimals.
    /// @param minShares The minimum amount of index tokens to receive in 18 decimals.
    function deposit(uint128 vaultId, uint128 assets, uint128 minShares) external {
        // fetch storage slot for vault by id
        Vault.Data storage vault = Vault.load(vaultId);

        // get vault asset
        address vaultAsset = vault.collateral.asset;

        // verify vault exists
        if (!vault.collateral.isEnabled) revert Errors.VaultDoesNotExist(vaultId);

        // fetch collateral data by asset
        Collateral.Data storage collateralData = Collateral.load(vaultAsset);

        // convert uint256 -> UD60x18; scales input to 18 decimals
        UD60x18 amountX18 = collateralData.convertTokenAmountToUd60x18(assets);

        // uint128 -> UD60x18
        UD60x18 depositCapX18 = collateralData.convertTokenAmountToUd60x18(vault.depositCap);

        // uint128 -> UD60x18
        UD60x18 totalCollateralDepositedX18 = collateralData.convertTokenAmountToUd60x18(vault.totalDeposited);

        // enforce new deposit + already deposited <= deposit cap
        _requireEnoughDepositCap(vaultAsset, amountX18, depositCapX18, totalCollateralDepositedX18);

        // add deposited amount to total deposited
        vault.totalDeposited += amountX18.intoUint128();

        // get the tokens
        IERC20(vaultAsset).safeTransferFrom(msg.sender, address(this), assets);

        // increase vault allowance to transfer tokens
        IERC20(vaultAsset).approve(address(vault.indexToken), assets);

        // then perform the acctual deposit
        uint256 shares = IERC4626(vault.indexToken).deposit(assets, msg.sender);

        // assert min shares minted
        if (shares < minShares) revert Errors.SlippageCheckFailed();

        // emit an event
        emit LogDeposit(vaultId, msg.sender, assets);
    }

    /// @notice Stakes a given amount of index tokens in the contract.
    /// @dev Index token holders must stake in order to earn fees distributions from the market making engine.
    /// @dev Invariants involved in the call:
    /// The sum of all staked assets SHOULD always equal the total stake value
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to stake, in 18 decimals.
    /// @param referralCode The referral code to use.
    /// @param isCustomReferralCode True if the referral code is a custom referral code.
    function stake(uint128 vaultId, uint128 shares, bytes memory referralCode, bool isCustomReferralCode) external {
        // fetch storage slot for vault by id
        Vault.Data storage vault = Vault.load(vaultId);

        // load distribution data
        Distribution.Data storage distributionData = vault.stakingFeeDistribution;

        // cast actor address to bytes32
        bytes32 actorId = bytes32(uint256(uint160(msg.sender)));

        // load actor distribution data
        Distribution.Actor storage actor = distributionData.actor[actorId];

        // calculate actor updated shares amount
        UD60x18 updatedActorShares = ud60x18(actor.shares).add(ud60x18(shares));

        // update actor staked shares
        distributionData.setActorShares(actorId, updatedActorShares);

        if (referralCode.length != 0) {
            Referral.Data storage referral = Referral.load(msg.sender);

            if (isCustomReferralCode) {
                CustomReferralConfiguration.Data storage customReferral =
                    CustomReferralConfiguration.load(string(referralCode));

                if (customReferral.referrer == address(0)) {
                    revert Errors.InvalidReferralCode();
                }

                referral.referralCode = referralCode;
                referral.isCustomReferralCode = true;
            } else {
                address referrer = abi.decode(referralCode, (address));

                if (referrer == msg.sender) {
                    revert Errors.InvalidReferralCode();
                }

                referral.referralCode = referralCode;
                referral.isCustomReferralCode = false;
            }
            emit LogReferralSet(msg.sender, referral.getReferrerAddress(), referralCode, isCustomReferralCode);
        }

        // transfer shares from actor
        IERC20(vault.indexToken).safeTransferFrom(msg.sender, address(this), shares);

        // emit an event
        emit LogStake(vaultId, msg.sender, shares);
    }

    ///.@notice Initiates a withdrawal request for a given amount of index tokens from the provided vault.
    /// @dev Invariants involved in the call:
    /// The shares to withdraw MUST be greater than zero.
    /// The user MUST have enough shares in their balance to initiate the withdrawal.
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to withdraw, in 18 decimals.
    function initiateWithdrawal(uint128 vaultId, uint128 shares) external {
        if (shares == 0) {
            revert Errors.ZeroInput("sharesAmount");
        }

        // fetch storage slot for vault by id
        Vault.Data storage vault = Vault.load(vaultId);

        // verify vault exists
        if (!vault.collateral.isEnabled) revert Errors.VaultDoesNotExist(vaultId);

        // increment withdrawal request counter and set withdrawal request id
        uint128 withdrawalRequestId = ++vault.withdrawalRequestIdCounter[msg.sender];

        // load storage slot for withdrawal request
        WithdrawalRequest.Data storage withdrawalRequest =
            WithdrawalRequest.load(vaultId, msg.sender, withdrawalRequestId);

        // verify user has enought shares
        if (IERC4626(vault.indexToken).balanceOf(msg.sender) < shares) revert Errors.NotEnoughShares();

        // update withdrawal request create time
        withdrawalRequest.timestamp = block.timestamp.toUint128();

        // update withdrawal request shares
        withdrawalRequest.shares = shares;

        // emit an event
        emit LogInitiateWithdrawal(vaultId, msg.sender, shares);
    }

    /// @notice Redeems a given amount of index tokens in exchange for collateral assets from the provided vault,
    /// after the withdrawal delay period has elapsed.
    /// @dev Invariants involved in the call:
    /// The withdrawalRequest MUST NOT be already fulfilled.
    /// The withdrawal delay period MUST have elapsed.
    /// Redeemed assets MUST meet or exceed minAssets
    /// @param vaultId The vault identifier.
    /// @param withdrawalRequestId The previously initiated withdrawal request id.
    /// @param minAssets The minimum amount of collateral to receive, in the underlying ERC20 decimals.
    function redeem(uint128 vaultId, uint128 withdrawalRequestId, uint256 minAssets) external {
        // fetch storage slot for vault by id
        Vault.Data storage vault = Vault.load(vaultId);

        // load storage slot for withdrawal request
        WithdrawalRequest.Data storage withdrawalRequest =
            WithdrawalRequest.load(vaultId, msg.sender, withdrawalRequestId);

        // revert if withdrawal request already filfilled
        if (withdrawalRequest.fulfilled) revert Errors.WithdrawalRequestAlreadyFullfilled();

        // revert if withdrawl request delay not yes passed
        if (withdrawalRequest.timestamp + vault.withdrawalDelay > block.timestamp) {
            revert Errors.WithdrawDelayNotPassed();
        }

        // redeem actual tokens from vault
        uint256 assets = IERC4626(vault.indexToken).redeem(withdrawalRequest.shares, msg.sender, msg.sender);

        // require at least min assets amount returned
        if (assets < minAssets) revert Errors.SlippageCheckFailed();

        // set withdrawal request to fulfilled
        withdrawalRequest.fulfilled = true;

        // emit an event
        emit LogRedeem(vaultId, msg.sender, assets);
    }

    /// @notice Unstakes a given amount of index tokens from the contract.
    /// @dev Unstaked tokens don't participate in fees distributions.
    /// @dev Invariants involved in the call:
    /// The user MUST have enough shares staked to perform the unstake.
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to unstake, in 18 decimals.
    function unstake(uint128 vaultId, uint256 shares) external {
        // fetch storage slot for vault by id
        Vault.Data storage vault = Vault.load(vaultId);

        // get vault staking fee distribution data
        Distribution.Data storage distributionData = vault.stakingFeeDistribution;

        // cast actor address to bytes32
        bytes32 actorId = bytes32(uint256(uint160(msg.sender)));

        // Accumulate shares before unstake
        distributionData.accumulateActor(actorId);

        // get acctor staked shares
        UD60x18 actorShares = distributionData.getActorShares(actorId);

        // verify actora has shares amount
        if (actorShares.lt(ud60x18(shares))) revert Errors.NotEnoughShares();

        // update actor shares
        distributionData.setActorShares(actorId, actorShares.sub(ud60x18(shares)));

        // transfer shares to user
        IERC20(vault.indexToken).safeTransfer(msg.sender, shares);

        // emit an event
        emit LogUnstake(vaultId, msg.sender, shares);
    }

    /// @notice Reverts if the deposit cap is exceeded.
    /// @param assetType The address of the asset
    /// @param amount The amount to deposit
    /// @param depositCap The deposit max deposit cap
    /// @param totalDeposited The total deposited amount so far
    function _requireEnoughDepositCap(
        address assetType,
        UD60x18 amount,
        UD60x18 depositCap,
        UD60x18 totalDeposited
    )
        internal
        pure
    {
        if (amount.add(totalDeposited).gt(depositCap)) {
            revert Errors.DepositCap(assetType, amount.intoUint256(), depositCap.intoUint256());
        }
    }
}
