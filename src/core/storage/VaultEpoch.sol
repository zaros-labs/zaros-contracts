//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Zaros dependencies
import { Distribution } from "./Distribution.sol";
import { ScalableMapping } from "./ScalableMapping.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

/**
 * @title Tracks collateral and debt distributions in a pool, for a specific collateral type, in a given epoch.
 *
 * Collateral is tracked with a distribution as opposed to a regular mapping because liquidations cause collateral to be
 * socialized. If collateral was tracked using a regular mapping, such socialization would be difficult and require
 * looping through individual balances, or some other sort of complex and expensive mechanism. Distributions make
 * socialization easy.
 *
 * Debt is also tracked in a distribution for the same reason, but it is additionally split in two distributions:
 * incoming and consolidated debt.
 *
 * Incoming debt is modified when a liquidations occurs.
 * Consolidated debt is updated when users interact with the system.
 */
library VaultEpoch {
    using Distribution for Distribution.Data;
    using SafeCast for int256;
    using ScalableMapping for ScalableMapping.Data;

    struct Data {
        int128 unconsolidatedDebt;
        int128 totalConsolidatedDebt;
        Distribution.Data accountsDebtDistribution;
        ScalableMapping.Data collateralAmounts;
        mapping(uint256 => int256) consolidatedDebtAmounts;
        mapping(uint128 => uint64) lastDelegationTime;
    }

    /**
     * @dev Updates the value per share of the incoming debt distribution.
     * Used for socialization during liquidations, and to bake in market changes.
     *
     * Called from:
     * - LiquidationModule.liquidate
     * - Pool.recalculateVaultCollateral (ticker)
     */
    function distributeDebtToAccounts(Data storage self, SD59x18 debtChange) internal {
        self.accountsDebtDistribution.distributeValue(debtChange);

        // Cache total debt here.
        // Will roll over to individual users as they interact with the system.
        self.unconsolidatedDebt = sd59x18(self.unconsolidatedDebt).sub(debtChange).intoInt256().toInt128();
    }

    /**
     * @dev Adjusts the debt associated with `accountId` by `amount`.
     * Used to add or remove debt from/to a specific account, instead of all accounts at once (use
     * distributeDebtToAccounts for that)
     */
    function assignDebtToAccount(
        Data storage self,
        uint128 accountId,
        SD59x18 amount
    )
        internal
        returns (SD59x18 newDebt)
    {
        SD59x18 currentDebt = sd59x18(self.consolidatedDebtAmounts[accountId]);
        self.consolidatedDebtAmounts[accountId] = currentDebt.add(amount).intoInt256();
        self.totalConsolidatedDebt = sd59x18(self.totalConsolidatedDebt).add(amount).intoInt256().toInt128();
        return currentDebt.add(amount);
    }

    /**
     * @dev Consolidates user debt as they interact with the system.
     *
     * Fluctuating debt is moved from incoming to consolidated debt.
     *
     * Called as a ticker from various parts of the system, usually whenever the
     * real debt of a user needs to be known.
     */
    function consolidateAccountDebt(Data storage self, uint128 accountId) internal returns (SD59x18 currentDebt) {
        SD59x18 newDebt = self.accountsDebtDistribution.accumulateActor(bytes32(uint256(accountId)));

        currentDebt = assignDebtToAccount(self, accountId, newDebt);
        self.unconsolidatedDebt = newDebt.intoInt256().toInt128();
    }

    function updateAccountPosition(Data storage self, uint128 accountId, UD60x18 collateralAmount) internal {
        bytes32 actorId = bytes32(uint256(accountId));

        // Ensure account debt is consolidated before we do next things.
        consolidateAccountDebt(self, accountId);

        self.collateralAmounts.set(actorId, collateralAmount);
        self.accountsDebtDistribution.setActorShares(actorId, ud60x18(self.collateralAmounts.shares[actorId]));
    }

    /**
     * @dev Returns the vault's total debt in this epoch, including the debt
     * that hasn't yet been consolidated into individual accounts.
     */
    function totalDebt(Data storage self) internal view returns (SD59x18) {
        return sd59x18(self.unconsolidatedDebt).add(sd59x18(self.totalConsolidatedDebt));
    }

    /**
     * @dev Returns an account's value in the Vault's collateral distribution.
     */
    function getAccountCollateral(Data storage self, uint128 accountId) internal view returns (UD60x18 amount) {
        return self.collateralAmounts.get(bytes32(uint256(accountId)));
    }
}
