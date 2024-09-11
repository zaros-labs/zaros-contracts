// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Collateral } from "./Collateral.sol";
import { Distribution } from "./Distribution.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { SD59x18 } from "@prb-math/SD59x18.sol";

library Vault {
    /// @notice ERC7201 storage location.
    bytes32 internal constant VAULT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Vault")) - 1));

    /// @param vaultId The unique identifier for the vault.
    /// @param totalDeposited The total amount of collateral assets deposited in the vault.
    /// @param totalCreditDelegationWeight The total amount of credit delegation weight in the vault.
    /// @param depositCap The maximum amount of collateral assets that can be deposited in the vault.
    /// @param withdrawalDelay The delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @param lockedCreditRatio The configured ratio that determines how much of the vault's total assets can't be
    /// withdrawn according to the Vault's total debt, in order to secure the credit delegation system.
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
        uint128 lockedCreditRatio;
        int128 unsettledDebtUsd;
        int128 settledDebtUsd;
        address indexToken;
        Collateral.Data collateral;
        Distribution.Data stakingFeeDistribution;
        EnumerableSet.UintSet[] connectedMarkets;
    }

    /// @notice Parameters required to create a new vault.
    /// @param vaultId The unique identifier for the vault to be created.
    /// @param depositCap The maximum amount of collateral assets that can be deposited in the vault.
    /// @param withdrawalDelay The delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @param indexToken The address of the index token used in the vault.
    /// @param collateral The collateral asset data associated with the vault.
    struct CreateParams {
        uint128 vaultId;
        uint128 depositCap;
        uint128 withdrawalDelay;
        address indexToken;
        Collateral.Data collateral;
    }

    /// @notice Parameters required to update an existing vault.
    /// @param vaultId The unique identifier for the vault to be updated.
    /// @param depositCap The new maximum amount of collateral assets that can be deposited in the vault.
    /// @param withdrawalDelay The new delay period, in seconds, before a withdrawal request can be fulfilled.
    /// @param collateral The updated collateral asset data associated with the vault.
    struct UpdateParams {
        uint128 vaultId;
        uint128 depositCap;
        uint128 withdrawalDelay;
        Collateral.Data collateral;
    }

    /// @notice Loads a {Vault} namespace.
    /// @param vaultId The vault identifier.
    /// @return vault The loaded vault storage pointer.
    function load(uint128 vaultId) internal pure returns (Data storage vault) {
        bytes32 slot = keccak256(abi.encode(VAULT_LOCATION, vaultId));
        assembly {
            vault.slot := slot
        }
    }

    // TODO: see if we need market id here or if we return the updated credit delegations to update the `MarketDebt`
    // state.
    /// @dev We use a `uint256` array because the vaults ids are stored at a `EnumerableSet.UintSet`.
    function updateVaultsCreditDelegation(uint256[] memory vaultsIds, uint128 marketId) internal { }

    /// @dev We use a `uint256` array because the vaults ids are stored at a `EnumerableSet.UintSet`.
    function updateVaultsUnsettledDebt(uint256[] memory vaultsIds, SD59x18 realizedDebtChangeUsdX18) internal { }

    /// @notice Updates an existing vault with the specified parameters.
    /// @dev Modifies the vault's settings. Reverts if the vault does not exist.
    /// @param params The struct containing the parameters required to update the vault.
    function update(UpdateParams memory params) internal {
        Data storage self = load(params.vaultId);

        if (self.vaultId == 0) {
            revert Errors.ZeroInput("vaultId");
        }

        self.depositCap = params.depositCap;
        self.withdrawalDelay = params.withdrawalDelay;
        self.collateral = params.collateral;
    }

    /// @notice Creates a new vault with the specified parameters.
    /// @dev Initializes the vault with the provided parameters. Reverts if the vault already exists.
    /// @param params The struct containing the parameters required to create the vault.
    function create(CreateParams memory params) internal {
        Data storage self = load(params.vaultId);

        if (self.vaultId != 0) {
            revert Errors.VaulttAlreadyEnabled(params.vaultId);
        }

        self.vaultId = params.vaultId;
        self.depositCap = params.depositCap;
        self.withdrawalDelay = params.withdrawalDelay;
        self.indexToken = params.indexToken;
        self.collateral = params.collateral;
    }
}
