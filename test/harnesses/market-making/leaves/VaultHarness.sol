// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Distribution } from "@zaros/market-making/leaves/Distribution.sol";

contract VaultHarness {
    function workaround_Vault_getIndexToken(uint128 vaultId) external view returns (address) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        return vaultData.indexToken;
    }

    function workaround_Vault_getActorStakedShares(
        uint128 vaultId,
        bytes32 actorId
    )
        external
        view
        returns (uint128)
    {
        Vault.Data storage vaultData = Vault.load(vaultId);

        Distribution.Data storage stakingData = vaultData.stakingFeeDistribution;

        return stakingData.actor[actorId].shares;
    }

    function workaround_Vault_getValuePerShare(
        uint128 vaultId
    )
        external
        view
        returns (int128)
    {
        Vault.Data storage vaultData = Vault.load(vaultId);

        Distribution.Data storage stakingData = vaultData.stakingFeeDistribution;

        return stakingData.valuePerShare;
    }

    function workaround_Vault_setTotalStakedShares(uint128 vaultId, uint128 newShares) external {
        Vault.Data storage vaultData = Vault.load(vaultId);

        Distribution.Data storage stakingData = vaultData.stakingFeeDistribution;

        stakingData.totalShares = newShares;
    }

    function workaround_Vault_getTotalStakedShares(uint128 vaultId) external view returns (uint128) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        Distribution.Data storage stakingData = vaultData.stakingFeeDistribution;

        return stakingData.totalShares;
    }

    function workaround_Vault_getWithdrawDelay(uint128 vaultId) external view returns (uint128) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        return vaultData.withdrawalDelay;
    }

    function workaround_Vault_getDepositCap(uint128 vaultId) external view returns (uint128) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        return vaultData.depositCap;
    }

    function workaround_Vault_getIsLive(uint128 vaultId) external view returns (bool) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        return vaultData.isLive;
    }

    function workaround_Vault_getVaultAsset(uint128 vaultId) external view returns (address) {
        Vault.Data storage vaultData = Vault.load(vaultId);

        return vaultData.collateral.asset;
    }

    function exposed_Vault_create(Vault.CreateParams memory params) external {
        Vault.create(params);
    }

    function exposed_Vault_update(Vault.UpdateParams memory params) external {
        Vault.update(params);
    }
}
