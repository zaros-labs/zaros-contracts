// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Collateral } from "./Collateral.sol";
import { Distribution } from "./Distribution.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

library Vault {
    /// @notice ERC7201 storage location.
    bytes32 internal constant VAULT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Vault")) - 1));

    /// @param totalDeposited The total amount of collateral assets deposited in the vault.
    /// @param depositCap The maximum amount of collateral assets that can be deposited in the vault.
    /// @param withdrawalDelay The delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @param unsettledDebtUsd The total amount of unsettled debt in USD.
    /// @param settledDebtUsd The total amount of settled debt in USD.
    /// @param indexToken The index token address.
    /// @param collateral The collateral asset data.
    /// @param stakingFeeDistribution `actor`: Stakers, `shares`: Staked index tokens, `valuePerShare`: WETH fee
    /// earned per share.
    /// @param connectedMarkets The list of connected market ids. Whenever there's an update, a new
    /// `EnumerableSet.UintSet` is created.
    struct Data {
        uint128 vaultId;
        uint128 totalDeposited;
        uint128 totalCreditDelegationWeight;
        uint128 depositCap;
        uint128 withdrawalDelay;
        int128 unsettledDebtUsd;
        int128 settledDebtUsd;
        address indexToken;
        Collateral.Data collateral;
        Distribution.Data stakingFeeDistribution;
        EnumerableSet.UintSet[] connectedMarkets;
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
