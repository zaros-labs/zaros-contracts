// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Vault } from "@zaros/market-making/leaves/Vault.sol";

contract VaultHarness {
    function workaround_Vault_getIndexToken(uint256 vaultId)
        external
        view
        returns (address)
    {
        Vault.Data storage vaultData = Vault.load(vaultId);

        return vaultData.indexToken;
    }
}