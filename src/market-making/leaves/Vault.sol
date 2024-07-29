// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Collateral } from "./Collateral.sol";
import { DebtDistribution } from "./DebtDistribution.sol";

library Vault {
    /// @notice ERC7201 storage location.
    bytes32 internal constant VAULT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Vault")) - 1));

    // TODO: pack storage slots
    struct Data {
        uint256 vaultId;
        uint256 totalDeposited;
        uint256 depositCap;
        uint256 withdrawalDelay;
        int256 totalUnsettledDebtUsd;
        int256 totalSettledDebtUsd;
        address indexToken;
        bool isDegenVault;
        Collateral.Data collateral;
        DebtDistribution.Data debtDistribution;
    }

    /// @notice Loads a {Vault}.
    /// @param vaultId The vault identifier.
    /// @return vault The loaded vault storage pointer.
    function load(uint256 vaultId) internal pure returns (Data storage vault) {
        bytes32 slot = keccak256(abi.encode(VAULT_LOCATION, vaultId));
        assembly {
            vault.slot := slot
        }
    }
}
