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

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

// TODO: think about referrals
contract VaultRouterBranch {
    using SafeERC20 for IERC20;
    using Distribution for Distribution.Data;
    using Referral for Referral.Data;

    /// @notice Counter for withdraw requiest ids
    uint256 private withdrawalRequestIdCounter;

    /// @notice Emitted when a user stakes shares.
    /// @param vaultId The ID of the vault which shares are staked.
    /// @param user The address of the user who staked the shares.
    /// @param shares The amount of shares staked by the user.
    event LogStake(uint256 indexed vaultId, address indexed user, uint256 shares);

    /// @notice Emitted when a user initiates a withdrawal from a vault.
    /// @param vaultId The ID of the vault from which the shares are being withdrawn.
    /// @param user The address of the user who initiated the withdrawal.
    /// @param shares The amount of shares to be withdrawn by the user.
    event LogInitiateWithdraw(uint256 indexed vaultId, address indexed user, uint256 shares);

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

    /// @notice Emited when a user deposist assets.
    /// @param vaultId The ID of the vault which assets are deposited.
    /// @param user The user that deposits the assets.
    /// @param assets The assets amount.
    event LogDeposit(uint256 indexed vaultId, address indexed user, uint256 assets);

    /// @notice Emited when a user deposist assets.
    /// @param vaultId The ID of the vault which assets are deposited.
    /// @param user The user that deposits the assets.
    /// @param shares The shares amount being redeemed.
    event LogRedeem(uint256 indexed vaultId, address indexed user, uint256 shares);

    /// @notice Returns the data and state of a given vault.
    /// @param vaultId The vault identifier.
    /// @return totalDeposited The total amount of collateral assets deposited in the vault.
    /// @return depositCap The maximum amount of collateral assets that can be deposited in the vault.
    /// @return withdrawalDelay The delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @return unsettledDebtUsd The total amount of unsettled debt in USD.
    /// @return settledDebtUsd The total amount of settled debt in USD.
    /// @return indexToken The index token address.
    /// @return collateral The collateral asset data.
    function getVaultData(uint128 vaultId)
        external
        view
        returns (
            uint128 totalDeposited,
            uint128 depositCap,
            uint128 withdrawalDelay,
            int128 unsettledDebtUsd,
            int128 settledDebtUsd,
            address indexToken,
            Collateral.Data memory collateral
        )
    {
        Vault.Data storage vault = Vault.load(vaultId);

        totalDeposited = vault.totalDeposited;
        depositCap = vault.depositCap;
        withdrawalDelay = vault.withdrawalDelay;
        unsettledDebtUsd = vault.unsettledDebtUsd;
        settledDebtUsd = vault.settledDebtUsd;
        indexToken = vault.indexToken;
        collateral = vault.collateral;
    }

    /// @notice Returns the swap rate from index token to collateral asset for the provided vault.
    /// @param vaultId The vault identifier.
    /// @return price The swap price from index token to collateral asset.
    function getIndexTokenSwapRate(uint256 vaultId) external view returns (uint256 price) {
        Vault.Data storage vault = Vault.load(vaultId);

        return IERC4626(vault.indexToken).previewRedeem(1 * 10 ** IERC4626(vault.collateral.asset).decimals());
    }

    /// @notice Deposits a given amount of collateral assets into the provided vault in exchange for index tokens.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param vaultId The vault identifier.
    /// @param assets The amount of collateral to deposit, in the underlying ERC20 decimals.
    /// @param minShares The minimum amount of index tokens to receive in 18 decimals.
    function deposit(uint256 vaultId, uint256 assets, uint256 minShares) external {
        Vault.Data storage vault = Vault.load(vaultId);
        vault.totalDeposited += assets;

        if (vault.totalDeposited > vault.depositCap) {
            revert Errors.DepositCapReached(vaultId, vault.totalDeposited, vault.depositCap);
        }

        IERC20(vault.collateral.asset).safeTransferFrom(msg.sender, address(this), assets);
        IERC20(vault.collateral.asset).approve(address(vault.indexToken), assets);
        uint256 shares = IERC4626(vault.indexToken).deposit(assets, msg.sender);

        if (shares < minShares) revert Errors.SlippageCheckFailed();

        emit LogDeposit(vaultId, msg.sender, assets);
    }

    /// @notice Stakes a given amount of index tokens in the contract.
    /// @dev Index token holders must stake in order to earn fees distributions from the market making engine.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to stake, in 18 decimals.
    /// @param referralCode The referral code to use.
    /// @param isCustomReferralCode True if the referral code is a custom referral code.
    function stake(uint256 vaultId, uint256 shares, bytes memory referralCode, bool isCustomReferralCode) external {
        Vault.Data storage vault = Vault.load(vaultId);
        Distribution.Data storage distributionData = vault.stakingFeeDistribution;
        bytes32 actorId = bytes32(uint256(uint160(msg.sender)));

        Distribution.Actor memory actor = distributionData.actor[actorId];
        UD60x18 updatedActorShares = ud60x18(actor.shares + SafeCast.toUint128(shares));

        distributionData.setActorShares(actorId, updatedActorShares);

        IERC20(vault.indexToken).safeTransferFrom(msg.sender, address(this), shares);

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

        emit LogStake(vaultId, msg.sender, shares);
    }

    ///.@notice Initiates a withdrawal request for a given amount of index tokens from the provided vault.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to withdraw, in 18 decimals.
    function initiateWithdrawal(uint256 vaultId, uint256 shares) external {
        if (shares == 0) {
            revert Errors.ZeroInput("sharesAmount");
        }

        Vault.Data storage vault = Vault.load(vaultId);
        WithdrawalRequest.Data storage withdrawalRequest =
            WithdrawalRequest.load(vaultId, msg.sender, withdrawalRequestIdCounter);

        if (IERC4626(vault.indexToken).balanceOf(msg.sender) < shares) revert Errors.NotEnoughShares();

        withdrawalRequest.timestamp = block.timestamp;
        withdrawalRequest.shares = shares;

        withdrawalRequestIdCounter += withdrawalRequestIdCounter + 1;

        emit LogInitiateWithdraw(vaultId, msg.sender, shares);
    }

    /// @notice Redeems a given amount of index tokens in exchange for collateral assets from the provided vault,
    /// after the withdrawal delay period has elapsed.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param vaultId The vault identifier.
    /// @param withdrawalRequestId The previously initiated withdrawal request id.
    /// @param minAssets The minimum amount of collateral to receive, in the underlying ERC20 decimals.
    function redeem(uint128 vaultId, uint128 withdrawalRequestId, uint256 minAssets) external {
        Vault.Data storage vault = Vault.load(vaultId);
        WithdrawalRequest.Data storage withdrawalRequest =
            WithdrawalRequest.load(vaultId, msg.sender, withdrawalRequestId);

        if (withdrawalRequest.fulfilled) revert Errors.WithdrawalRequestAlreadyFullfilled();

        if (withdrawalRequest.timestamp + vault.withdrawalDelay > block.timestamp) {
            revert Errors.WithdrawDelayNotPassed();
        }

        uint256 assets = IERC4626(vault.indexToken).redeem(withdrawalRequest.shares, address(this), msg.sender);

        if (assets < minAssets) revert Errors.SlippageCheckFailed();

        withdrawalRequest.fulfilled = true;

        emit LogRedeem(vaultId, msg.sender, assets);
    }

    /// @notice Unstakes a given amount of index tokens from the contract.
    /// @dev Unstaked tokens don't participate in fees distributions.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to unstake, in 18 decimals.
    function unstake(uint256 vaultId, uint256 shares) external {
        Vault.Data storage vault = Vault.load(vaultId);
        Distribution.Data storage distributionData = vault.stakingFeeDistribution;
        bytes32 actorId = bytes32(uint256(uint160(msg.sender)));

        UD60x18 actorShares = distributionData.getActorShares(actorId);
        if (actorShares.lt(ud60x18(shares))) revert Errors.NotEnoughShares();

        // Accumulate shares before unstake
        distributionData.accumulateActor(actorId);
        distributionData.setActorShares(actorId, actorShares.sub(ud60x18(shares)));

        IERC20(vault.indexToken).safeTransfer(msg.sender, shares);

        emit LogUnstake(vaultId, msg.sender, shares);
    }
}
