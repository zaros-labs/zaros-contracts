// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { WithdrawalRequest } from "@zaros/market-making/leaves/WithdrawalRequest.sol";

// Open Zeppelin dependencies
import { IERC20, IERC4626, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

// TODO: think about referrals
contract VaultRouterBranch {
    using SafeERC20 for IERC20;

    /// @notice Returns the data and state of a given vault.
    /// @param vaultId The vault identifier.
    /// @return totalDeposited The total amount of collateral assets deposited in the vault.
    /// @return depositCap The maximum amount of collateral assets that can be deposited in the vault.
    /// @return withdrawalDelay The delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @return unsettledDebtUsd The total amount of unsettled debt in USD.
    /// @return settledDebtUsd The total amount of settled debt in USD.
    /// @return indexToken The index token address.
    /// @return collateral The collateral asset data.
    function getVaultData(uint256 vaultId)
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
    function getIndexTokenSwapRate(uint128 vaultId) external view returns (uint256 price) { }

    /// @notice Deposits a given amount of collateral assets into the provided vault in exchange for index tokens.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param vaultId The vault identifier.
    /// @param assets The amount of collateral to deposit, in the underlying ERC20 decimals.
    /// @param minShares The minimum amount of index tokens to receive in 18 decimals.
    function deposit(uint128 vaultId, uint256 assets, uint256 minShares) external {
        // TODO: implement

        Vault.Data storage vault = Vault.load(vaultId);

        IERC20(vault.collateral.asset).safeTransferFrom(msg.sender, address(this), assets);
        uint256 shares = IERC4626(vault.indexToken).deposit(assets, msg.sender);

        // TODO: add custom error
        if (shares < minShares) revert();
    }

    /// @notice Stakes a given amount of index tokens in the contract.
    /// @dev Index token holders must stake in order to earn fees distributions from the market making engine.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to stake, in 18 decimals.
    /// @param referralCode The referral code to use.
    /// @param isCustomReferralCode True if the referral code is a custom referral code.
    function stake(uint128 vaultId, uint256 shares, bytes memory referralCode, bool isCustomReferralCode) external { }

    ///.@notice Initiates a withdrawal request for a given amount of index tokens from the provided vault.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to withdraw, in 18 decimals.
    function initiateWithdrawal(uint128 vaultId, uint256 shares) external { }

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

        // TODO: add custom error
        if (withdrawalRequest.fulfilled) revert();

        uint256 assets = IERC4626(vault.indexToken).redeem(withdrawalRequest.shares, address(this), msg.sender);

        // TODO: add custom error
        if (withdrawalRequest.timestamp + vault.withdrawalDelay < block.timestamp) revert();

        // TODO: add custom error
        if (assets < minAssets) revert();
    }

    /// @notice Unstakes a given amount of index tokens from the contract.
    /// @dev Unstaked tokens don't participate in fees distributions.
    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to unstake, in 18 decimals.
    function unstake(uint128 vaultId, uint256 shares) external { }
}
