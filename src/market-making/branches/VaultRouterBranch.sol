// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { WithdrawalRequest } from "@zaros/market-making/leaves/WithdrawalRequest.sol";

// Open Zeppelin dependencies
import { IERC20, IERC4626, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

// TODO: think about referrals
contract VaultRouterBranch {
    using SafeERC20 for IERC20;

    /// @notice Returns the data and state of a given vault.
    /// @param vaultId The vault identifier.
    /// @return vaultData The vault data.
    function getVaultData(uint256 vaultId) external pure returns (Vault.Data memory) {
        return Vault.load(vaultId);
    }

    /// @notice Returns the swap rate from index token to collateral asset for the provided vault.
    /// @param vaultId The vault identifier.
    /// @return price The swap price from index token to collateral asset.
    function getIndexTokenSwapRate(uint256 vaultId) external view returns (uint256 price) { }

    /// @notice Deposits a given amount of collateral assets into the provided vault in exchange for index tokens.
    /// @param vaultId The vault identifier.
    /// @param assets The amount of collateral to deposit, in the underlying ERC20 decimals.
    /// @param minShares The minimum amount of index tokens to receive in 18 decimals.
    function deposit(uint256 vaultId, uint256 assets, uint256 minShares) external {
        // TODO: implement

        Vault.Data storage vault = Vault.load(vaultId);

        IERC20(vault.collateral.asset).safeTransferFrom(msg.sender, address(this), assets);
        uint256 shares = IERC4626(vault.indexToken).deposit(assets, msg.sender);

        // TODO: add custom error
        if (shares < minShares) revert();
    }

    /// @notice Stakes a given amount of index tokens in the contract.
    /// @dev Index token holders must stake in order to earn fees distributions from the market making engine.
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to stake, in 18 decimals.
    function stake(uint256 vaultId, uint256 shares) external { }

    ///.@notice Initiates a withdrawal request for a given amount of index tokens from the provided vault.
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to withdraw, in 18 decimals.
    function initiateWithdrawal(uint256 vaultId, uint256 shares) external { }

    /// @notice Redeems a given amount of index tokens in exchange for collateral assets from the provided vault,
    /// after the withdrawal delay period has elapsed.
    /// @param vaultId The vault identifier.
    /// @param withdrawalRequestId The previously initiated withdrawal request id.
    /// @param minAssets The minimum amount of collateral to receive, in the underlying ERC20 decimals.
    function redeem(uint256 vaultId, uint256 withdrawalRequestId, uint256 minAssets) external {
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
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to unstake, in 18 decimals.
    function unstake(uint256 vaultId, uint256 shares) external { }
}
