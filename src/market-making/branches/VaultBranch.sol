// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Vault } from "@zaros/market-making/leaves/Vault.sol";

contract VaultBranch {
    function getVaultData(uint256 vaultId) external view returns (Vault.Data memory) {
        return Vault.load(vaultId);
    }

    function deposit(uint128 vaultId, uint256 amount) external { }

    // TODO: should we delay withdrawals?
    function withdraw(uint128 vaultId, uint256 amount) external { }
}
