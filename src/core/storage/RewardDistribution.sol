//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

// Zaros dependencies
import { ParameterError } from "../../utils/Errors.sol";
import { IRewardDistributor } from "../interfaces/external/IRewardDistributor.sol";
import { Distribution } from "./Distribution.sol";
import { RewardDistributionClaimStatus } from "./RewardDistributionClaimStatus.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

/**
 * @title Used by vaults to track rewards for its participants. There will be one of these for each pool, collateral
 * type, and distributor combination.
 */
library RewardDistribution {
    using SafeCast for int256;

    struct Data {
        /**
         * @dev The 3rd party smart contract which holds/mints tokens for distributing rewards to vault participants.
         */
        IRewardDistributor distributor;
        /**
         * @dev Available slot.
         */
        uint128 __slotAvailableForFutureUse;
        /**
         * @dev The value of the rewards in this entry.
         */
        uint128 rewardPerShare;
        /**
         * @dev The status for each actor, regarding this distribution's entry.
         */
        mapping(uint256 => RewardDistributionClaimStatus.Data) claimStatus;
        /**
         * @dev Value to be distributed as rewards in a scheduled form.
         */
        int128 scheduledValue;
        /**
         * @dev Date at which the entry's rewards will begin to be claimable.
         *
         * Note: Set to <= block.timestamp to distribute immediately to currently participating users.
         */
        uint64 start;
        /**
         * @dev Time span after the start date, in which the whole of the entry's rewards will become claimable.
         */
        uint32 duration;
        /**
         * @dev Date on which this distribution entry was last updated.
         */
        uint32 lastUpdate;
    }

    /**
     * @dev Distributes rewards into a new rewards distribution entry.
     *
     * Note: this function allows for more special cases such as distributing at a future date or distributing over
     * time.
     * If you want to apply the distribution to the pool, call `distribute` with the return value. Otherwise, you can
     * record this independently as well.
     */
    function distribute(
        Data storage self,
        Distribution.Data storage dist,
        SD59x18 amount,
        uint64 start,
        uint32 duration
    )
        internal
        returns (SD59x18 diff)
    {
        UD60x18 totalShares = ud60x18(dist.totalShares);

        if (totalShares.isZero()) {
            revert ParameterError.InvalidParameter("amount", "can't distribute to empty distribution");
        }

        uint256 currentTime = block.timestamp;

        // Unlocks the entry's distributed amount into its value per share.
        diff = diff.add(updateEntry(self, totalShares));

        // If the current time is past the end of the entry's duration,
        // update any rewards which may have accrued since last run.
        // (instant distribution--immediately disperse amount).
        if (start + duration <= currentTime) {
            diff = diff.add(amount.div(totalShares.intoSD59x18()));

            self.lastUpdate = 0;
            self.start = 0;
            self.duration = 0;
            self.scheduledValue = 0;
            // Else, schedule the amount to distribute.
        } else {
            self.scheduledValue = amount.toInt128();

            self.start = start;
            self.duration = duration;

            // The amount is actually the amount distributed already *plus* whatever has been specified now.
            self.lastUpdate = 0;

            diff = diff.add(updateEntry(self, totalShares));
        }
    }

    /**
     * @dev Updates the total shares of a reward distribution entry, and releases its unlocked value into its value per
     * share, depending on the time elapsed since the start of the distribution's entry.
     *
     * Note: call every time before `totalShares` changes.
     */
    function updateEntry(Data storage self, UD60x18 totalSharesAmount) internal returns (SD59x18) {
        // Cannot process distributed rewards if a pool is empty or if it has no rewards.
        SD59x18 scheduledValue = sd59x18(int256(self.scheduledValue));
        if (scheduledValue.isZero() || totalSharesAmount.isZero()) {
            return sd59x18(int256(0));
        }

        UD60x18 currentTime = ud60x18(uint256(block.timestamp));
        UD60x18 duration = ud60x18(uint256(self.duration));
        UD60x18 lastUpdate = ud60x18(uint256(self.lastUpdate));
        UD60x18 start = ud60x18(uint256(self.start));
        SD59x18 valuePerShareChange = sd59x18(0);

        // Cannot update an entry whose start date has not being reached.
        if (currentTime < self.start) {
            return 0;
        }

        // If the entry's duration is zero and the its last update is zero,
        // consider the entry to be an instant distribution.
        if (duration.isZero() && lastUpdate.lt(start)) {
            // Simply update the value per share to the total value divided by the total shares.
            valuePerShareChange = scheduledValue.div(totalSharesAmount.intoSD59x18());
            // Else, if the last update was before the end of the duration.
        } else if (lastUpdate.lt(start.add(duration))) {
            // Determine how much was previously distributed.
            // If the last update is zero, then nothing was distributed,
            // otherwise the amount is proportional to the time elapsed since the start.
            SD59x18 lastUpdateDistributed = lastUpdate.lt(start)
                ? sd59x18(0)
                : scheduledValue.mul(lastUpdate.sub(start).intoSD59x18()).div(duration.intoSD59x18());

            // If the current time is beyond the duration, then consider all scheduled value to be distributed.
            // Else, the amount distributed is proportional to the elapsed time.
            SD59x18 currentUpdateDistributed = scheduledValue;
            if (currentTime.lt(start.add(duration))) {
                // Note: Not using an intermediate time ratio variable
                // in the following calculation to maintain precision.
                currentUpdateDistributed =
                    (currentUpdateDistributed.mul(currentTime.sub(start))).intoSD59x18().div(duration.intoSD59x18());
            }

            // The final value per share change is the difference between what is to be distributed and what was
            // distributed.
            valuePerShareChange =
                (currentUpdateDistributed.sub(lastUpdateDistributed)).div(totalSharesAmount.intoSD59x18());
        }

        self.lastUpdate = currentTime.toUint32();

        return valuePerShareChange;
    }
}
