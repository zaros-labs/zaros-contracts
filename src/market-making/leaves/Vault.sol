// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Collateral } from "./Collateral.sol";
import { CreditDelegation } from "./CreditDelegation.sol";
import { Distribution } from "./Distribution.sol";
import { MarketDebt } from "@zaros/market-making/leaves/MarketDebt.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";


/// @dev Vault's debt for ADL determination purposes:
///  unrealized debt + realized debt + unsettled debt + settled debt + requested usdz.
/// This means if the engine fails to report the unrealized debt properly, its users will unexpectedly be deleveraged.
/// The MM engine protects LPs by taking into account the requested USDz.
/// @dev Vault's debt for credit delegation purposes = unsettledDebtUsd (comes from each market's realized debt) + settledDebtUsd + unrealized debt of each market (realized must always be distributed to unsettled following the Debt Distribution System)
/// @dev Vault's debt for asset settlement purposes = unsettledDebtUsd + settledDebtUsd
/// @dev A swap adds `settledDebt` but subtracts `unsettledDebt`. The Vault earns a swap fee for the inconvenience, allocated as additional WETH staking rewards.
library Vault {
    /// @notice ERC7201 storage location.
    bytes32 internal constant VAULT_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Vault")) - 1));

    /// @param totalDeposited The total amount of collateral assets deposited in the vault.
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

    /// @notice Loads a {Vault} namespace.
    /// @param vaultId The vault identifier.
    /// @return vault The loaded vault storage pointer.
    function load(uint128 vaultId) internal pure returns (Data storage vault) {
        bytes32 slot = keccak256(abi.encode(VAULT_LOCATION, vaultId));
        assembly {
            vault.slot := slot
        }
    }

    function getLockedCreditCapacityUsd(Data storage self) internal view returns (SD59x18) {
        return getTotalCreditCapacityUsd(self).mul(ud60x18(self.lockedCreditRatio).intoSD59x18());
    }

    function getTotalCreditCapacityUsd(Data storage self) internal view returns (SD59x18 vaultCreditCapacityUsdX18) {
        Collateral.Data storage collateral = self.collateral;
        // TODO: update self.totalDeposited to ERC4626::totalAssets
        UD60x18 totalAssetsUsdX18 = collateral.getPrice().mul(ud60x18(self.totalDeposited));

        vaultCreditCapacityUsdX18 = totalAssetsUsdX18.intoSD59x18().sub(sd59x18(self.unsettledDebtUsd));
    }

    function recalculateUnsettledDebt(Data storage self, uint128 marketIdToSkip) internal { }

    // TODO: see if we need market id here or if we return the updated credit delegations to update the `MarketDebt`
    // state.
    /// @dev We use a `uint256` array because the vaults ids are stored at a `EnumerableSet.UintSet`.
    function updateVaultsCreditDelegation(uint256[] memory vaultsIds, uint128 marketId) internal {
        for (uint256 i; i < vaultsIds.length; i++) {
            // load the vault storage pointer
            Data storage self = load(uint128(vaultsIds[i]));
            // we must always recalculate the credit capacity before updating a vault's credit delegation
            recalculateUnsettledDebt(self);
            // load the credit delegation to the given market id
            CreditDelegation.Data storage creditDelegation = CreditDelegation.load(self.vaultId, marketId);

            // get the latest credit delegation share of the vault's credit capacity
            UD60x18 creditDelegationShareX18 =
                ud60x18(creditDelegation.weight).div(ud60x18(self.totalCreditDelegationWeight));

            UD60x18 newCreditDelegationUsdX18 = getTotalCreditCapacityUsd(self).mul(creditDelegationShareX18);

            MarketDebt.Data storage marketDebt = MarketDebt.load(marketId);

            marketDebt.updateVault
        }
    }

    /// @dev We use a `uint256` array because the vaults ids are stored at a `EnumerableSet.UintSet`.
    function updateVaultsUnsettledDebt(uint256[] memory vaultsIds, SD59x18 realizedDebtChangeUsdX18) internal { }
}
