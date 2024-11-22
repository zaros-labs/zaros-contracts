// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

// todo: come back here, update vault and credit delegation flows following latest market updates
library CreditDelegation {
    using SafeCast for int256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant CREDIT_DELEGATION_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.CreditDelegation")) - 1));

    // TODO: apply max debt per share to market debt calculation
    // TODO: natspec
    // todo: move vault debt distribution logic to here
    struct Data {
        uint128 vaultId;
        uint128 marketId;
        uint128 weight;
        uint128 valueUsd;
        uint128 maxDebtPerShare;
        uint128 lastVaultDistributedWethRewardPerShare;
        int128 lastVaultDistributedUnrealizedDebtUsdPerShare;
        int128 lastVaultDistributedRealizedDebtUsdPerShare;
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

    /// @notice Updates this vault's credit delegation last distributed debt and reward values.
    /// @dev This function must be called whenever a vault accumulates debt and reward distributed by a market, and
    /// this leaf is used to support accounting at the Vault and Market leaves.
    /// @param self The credit delegation storage pointer.
    /// @param vaultDistributedWethRewardX18 The vault's distributed WETH reward.
    /// @param vaultDistributedUnrealizedDebtUsdX18 The vault's distributed unrealized debt in USD.
    /// @param vaultDistributedRealizedDebtUsdX18 The vault's distributed realized debt in USD.
    function updateVaultLastDistributedDebtAndReward(
        Data storage self,
        UD60x18 vaultDistributedWethRewardX18,
        SD59x18 vaultDistributedUnrealizedDebtUsdX18,
        SD59x18 vaultDistributedRealizedDebtUsdX18
    )
        internal
    {
        self.lastVaultDistributedWethRewardPerShare = vaultDistributedWethRewardX18.intoUint128();
        self.lastVaultDistributedUnrealizedDebtUsdPerShare =
            vaultDistributedUnrealizedDebtUsdX18.intoInt256().toInt128();
        self.lastVaultDistributedRealizedDebtUsdPerShare = vaultDistributedRealizedDebtUsdX18.intoInt256().toInt128();
    }
}
