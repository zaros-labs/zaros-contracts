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

library VaultEpoch {
    using Distribution for Distribution.Data;
    using SafeCast for int256;
    using ScalableMapping for ScalableMapping.Data;

    struct Data {
        int128 unconsolidatedDebt;
        int128 totalConsolidatedDebt;
        Distribution.Data accountsDebtDistribution;
        ScalableMapping.Data collateralAmounts;
        mapping(uint256 index => int256) consolidatedDebtAmounts;
        mapping(uint128 accountId => uint64) lastDelegationTime;
    }

    function distributeDebtToAccounts(Data storage self, SD59x18 debtChange) internal {
        self.accountsDebtDistribution.distributeValue(debtChange);

        // Cache total debt here.
        // Will roll over to individual users as they interact with the system.
        self.unconsolidatedDebt = sd59x18(self.unconsolidatedDebt).sub(debtChange).intoInt256().toInt128();
    }

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

    function totalDebt(Data storage self) internal view returns (SD59x18) {
        return sd59x18(self.unconsolidatedDebt).add(sd59x18(self.totalConsolidatedDebt));
    }

    function getAccountCollateral(Data storage self, uint128 accountId) internal view returns (UD60x18 amount) {
        return self.collateralAmounts.get(bytes32(uint256(accountId)));
    }
}
