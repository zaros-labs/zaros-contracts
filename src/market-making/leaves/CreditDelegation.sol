// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { SD59x18 } from "@prb-math/SD59x18.sol";

library CreditDelegation {
    using SafeCast for int256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant CREDIT_DELEGATION_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.CreditDelegation")) - 1));

    // TODO: apply max debt per share to market debt calculation
    struct Data {
        uint128 vaultId;
        uint128 marketId;
        uint128 weight;
        uint128 maxDebtPerShare;
        int128 lastVaultDistributedUnrealizedDebtUsd;
        int128 lastVaultDistributedRealizedDebtUsd;
    }

    /// @notice Loads a {CreditDelegation}.
    /// @param vaultId the Vault providing a share of its credit to the market.
    /// @param marketId the perp market receiving the credit.
    /// @return creditDelegation The loaded credit delegation storage pointer.
    function load(uint128 vaultId, uint256 marketId) internal pure returns (Data storage creditDelegation) {
        bytes32 slot = keccak256(abi.encode(CREDIT_DELEGATION_LOCATION, vaultId, marketId));
        assembly {
            creditDelegation.slot := slot
        }
    }

    /// @notice Updates this vault's credit delegation last distributed debt values.
    /// @dev This function must be called whenever a vault accumulates debt distributed by a market, and this leaf is
    /// used to support accounting at the Vault and Market leaves.
    /// @param self The credit delegation storage pointer.
    /// @param vaultDistributedUnrealizedDebtUsd The vault's distributed unrealized debt in USD.
    /// @param vaultDistributedRealizedDebtUsd The vault's distributed realized debt in USD.
    function updateVaultLastDistributedDebt(
        Data storage self,
        SD59x18 vaultDistributedUnrealizedDebtUsd,
        SD59x18 vaultDistributedRealizedDebtUsd
    )
        internal
    {
        self.lastVaultDistributedUnrealizedDebtUsd = vaultDistributedUnrealizedDebtUsd.intoInt256().toInt128();
        self.lastVaultDistributedRealizedDebtUsd = vaultDistributedRealizedDebtUsd.intoInt256().toInt128();
    }
}
