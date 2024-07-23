// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Vault } from "@zaros/market-making/leaves/Vault.sol";

// Open Zeppelin dependencies
import { IERC20, IERC4626, SafeERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

contract VaultRouterBranch {
    using SafeERC20 for IERC20;

    /// @notice Returns the data and state of a given vault.
    /// @param vaultId The vault identifier.
    /// @return vaultData The vault data.
    function getVaultData(uint256 vaultId) external pure returns (Vault.Data memory) {
        return Vault.load(vaultId);
    }

    // TODO: should we delay deposits?
    /// @notice Deposits a given amount of collateral assets into the provided vault in exchange for index tokens.
    /// @param vaultId The vault identifier.
    /// @param assets The amount of collateral to deposit, in the underlying ERC20 decimals.
    /// @param minShares The minimum amount of index tokens to receive in 18 decimals.
    function deposit(uint256 vaultId, uint256 assets, uint256 minShares) external {
        // TODO: implement

        Vault.Data storage vault = Vault.load(vaultId);

        IERC20(vault.collateral.asset).safeTransferFrom(msg.sender, address(this), assets);
        uint256 shares = IERC4626(vault.indexToken).deposit(assets, msg.sender);

        if (shares < minShares) {
            // TODO: add custom error
            revert();
        }
    }

    /// @notice Mints a given amount of index tokens in exchange for collateral assets to the provided vault.
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to mint in 18 decimals.
    /// @param minAssets The minimum amount of collateral to receive, in the underlying ERC20 decimals.
    function mint(uint256 vaultId, uint256 shares, uint256 minAssets) external {
        Vault.Data storage vault = Vault.load(vaultId);

        // purposefully ignore return value
        uint256 assets = IERC4626(vault.indexToken).mint(shares, msg.sender);

        if (assets < minAssets) {
            // TODO: add custom error
            revert();
        }
    }

    // TODO: should we delay withdrawals?
    /// @notice Withdraws a given amount of collateral assets from the provided vault in exchange for index tokens.
    /// @param vaultId The vault identifier.
    /// @param assets The amount of collateral to withdraw, in the underlying ERC20 decimals.
    /// @param minShares The minimum amount of index tokens to receive in 18 decimals.
    function withdraw(uint256 vaultId, uint256 assets, uint256 minShares) external {
        Vault.Data storage vault = Vault.load(vaultId);

        // purposefully ignore return value
        uint256 shares = IERC4626(vault.indexToken).withdraw(assets, msg.sender, msg.sender);

        if (shares < minShares) {
            // TODO: add custom error
            revert();
        }
    }

    /// @notice Redeems a given amount of index tokens in exchange for collateral assets from the provided vault.
    /// @param vaultId The vault identifier.
    /// @param shares The amount of index tokens to redeem in 18 decimals.
    /// @param minAssets The minimum amount of collateral to receive, in the underlying ERC20 decimals.
    function redeem(uint256 vaultId, uint256 shares, uint256 minAssets) external {
        Vault.Data storage vault = Vault.load(vaultId);

        // purposefully ignore return value
        uint256 assets = IERC4626(vault.indexToken).redeem(shares, msg.sender, msg.sender);

        if (assets < minAssets) {
            // TODO: add custom error
            revert();
        }
    }
}
