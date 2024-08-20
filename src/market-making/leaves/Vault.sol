// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Collateral } from "./Collateral.sol";
import { Distribution } from "./Distribution.sol";

library Vault {
    /// @notice ERC7201 storage location.
    bytes32 internal constant VAULT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Vault")) - 1));

    // TODO: pack storage slots
    // TODO: add list of markets that this Vault provides credit to.
    /// @param totalDeposited The total amount of collateral assets deposited in the vault.
    /// @param depositCap The maximum amount of collateral assets that can be deposited in the vault.
    /// @param withdrawalDelay The delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @param unsettledDebtUsd The total amount of unsettled debt in USD.
    /// @param settledDebtUsd The total amount of settled debt in USD.
    /// @param indexToken The index token address.
    /// @param collateral The collateral asset data.
    /// @param feeDistribution `actor`: Stakers, `shares`: Staked index tokens, `valuePerShare`: WETH fee earned per
    /// share.
    struct Data {
        uint256 vaultId;
        uint256 totalDeposited;
        uint256 depositCap;
        uint256 withdrawalDelay;
        int256 unsettledDebtUsd;
        int256 settledDebtUsd;
        address indexToken;
        Collateral.Data collateral;
        Distribution.Data feeDistribution;
    }

    /// @notice Loads a {Vault} namespace.
    /// @param vaultId The vault identifier.
    /// @return vault The loaded vault storage pointer.
    function load(uint256 vaultId) internal pure returns (Data storage vault) {
        bytes32 slot = keccak256(abi.encode(VAULT_LOCATION, vaultId));
        assembly {
            vault.slot := slot
        }
    }
}
