// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Distribution } from "@zaros/market-making/leaves/Distribution.sol";

contract VaultHarness {
    function workaround_Vault_getIndexToken(uint256 vaultId)
        external
        view
        returns (address)
    {
        Vault.Data storage vaultData = Vault.load(vaultId);

        return vaultData.indexToken;
    }

    function workaround_Vault_getActorStakedShares(uint256 vaultId, bytes32 actorId) external view returns (uint256) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        Distribution.Data storage stakingData = vaultData.stakingFeeDistribution;

        return stakingData.actor[actorId].shares;
    }

    function workaround_Vault_getTotalStakedShares(uint256 vaultId) external view returns (uint256) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        Distribution.Data storage stakingData = vaultData.stakingFeeDistribution;

        return stakingData.totalShares;
    }
}