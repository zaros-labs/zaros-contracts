//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

// Zaros dependencies
import {DistributionActor} from "./DistributionActor.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

/**
 * @title Data structure that allows you to track some global value, distributed amongst a set of actors.
 *
 * The total value can be scaled with a valuePerShare multiplier, and individual actor shares can be calculated as their amount of shares times this multiplier.
 *
 * Furthermore, changes in the value of individual actors can be tracked since their last update, by keeping track of the value of the multiplier, per user, upon each interaction. See DistributionActor.lastValuePerShare.
 *
 * A distribution is similar to a ScalableMapping, but it has the added functionality of being able to remember the previous value of the scalar multiplier for each actor.
 *
 * Whenever the shares of an actor of the distribution is updated, you get information about how the actor's total value changed since it was last updated.
 */
library Distribution {
    using SafeCastU128 for uint128;
    using SafeCastU256 for uint256;
    using SafeCastI128 for int128;
    using SafeCastI256 for int256;

    /**
     * @dev Thrown when an attempt is made to distribute value to a distribution
     * with no shares.
     */
    error Zaros_Distribution_EmptyDistribution();

    struct Data {
        /**
         * @dev The total number of shares in the distribution.
         */
        uint128 totalShares;
        /**
         * @dev The value per share of the distribution, represented as a high precision decimal.
         */
        int128 valuePerShare;
        /**
         * @dev Tracks individual actor information, such as how many shares an actor has, their lastValuePerShare, etc.
         */
        mapping(bytes32 => DistributionActor.Data) actorInfo;
    }

    /**
     * @dev Inflates or deflates the total value of the distribution by the given value.
     *
     * The value being distributed ultimately modifies the distribution's valuePerShare.
     */
    function distributeValue(Data storage self, SD59x18 value) internal {
        if (value.eq(sd59x18(0))) {
            return;
        }

        UD60x18 totalShares = ud60x18(self.totalShares);

        if (totalShares.eq(ud60x18(0))) {
            revert Zaros_Distribution_EmptyDistribution();
        }

        int256 valueD45 = valueD18 * DecimalMath.UNIT_PRECISE_INT;
        int256 deltaValuePerShareD27 = valueD45 / totalSharesD18.toInt();

        self.valuePerShareD27 += deltaValuePerShareD27.to128();
    }

    /**
     * @dev Updates an actor's number of shares in the distribution to the specified amount.
     *
     * Whenever an actor's shares are changed in this way, we record the distribution's current valuePerShare into the actor's lastValuePerShare record.
     *
     * Returns the the amount by which the actors value changed since the last update.
     */
    function setActorShares(
        Data storage self,
        bytes32 actorId,
        UD60x18 newActorShares
    ) internal returns (int256 valueChangeD18) {
        valueChangeD18 = getActorValueChange(self, actorId);

        DistributionActor.Data storage actor = self.actorInfo[actorId];

        uint128 sharesUint128D18 = newActorSharesD18.to128();
        self.totalSharesD18 = self.totalSharesD18 + sharesUint128D18 - actor.sharesD18;

        actor.sharesD18 = sharesUint128D18;
        _updateLastValuePerShare(self, actor, newActorSharesD18);
    }

    /**
     * @dev Updates an actor's lastValuePerShare to the distribution's current valuePerShare, and
     * returns the change in value for the actor, since their last update.
     */
    function accumulateActor(
        Data storage self,
        bytes32 actorId
    ) internal returns (SD59x18 valueChange) {
        DistributionActor.Data storage actor = self.actorInfo[actorId];
        return _updateLastValuePerShare(self, actor, actor.sharesD18);
    }

    /**
     * @dev Calculates how much an actor's value has changed since its shares were last updated.
     *
     * This change is calculated as:
     * Since `value = valuePerShare * shares`,
     * then `delta_value = valuePerShare_now * shares - valuePerShare_then * shares`,
     * which is `(valuePerShare_now - valuePerShare_then) * shares`,
     * or just `delta_valuePerShare * shares`.
     */
    function getActorValueChange(
        Data storage self,
        bytes32 actorId
    ) internal view returns (SD59x18 valueChange) {
        return _getActorValueChange(self, self.actorInfo[actorId]);
    }

    /**
     * @dev Returns the number of shares owned by an actor in the distribution.
     */
    function getActorShares(
        Data storage self,
        bytes32 actorId
    ) internal view returns (UD60x18 shares) {
        return ud60x18(self.actorInfo[actorId].shares);
    }

    /**
     * @dev Returns the distribution's value per share in normal precision (18 decimals).
     * @param self The distribution whose value per share is being queried.
     * @return The value per share in 18 decimal precision.
     */
    function getValuePerShare(Data storage self) internal view returns (int256) {
        return self.valuePerShareD27.to256().downscale(DecimalMath.PRECISION_FACTOR);
    }

    function _updateLastValuePerShare(
        Data storage self,
        DistributionActor.Data storage actor,
        uint256 newActorShares
    ) private returns (int256 valueChangeD18) {
        valueChangeD18 = _getActorValueChange(self, actor);

        actor.lastValuePerShareD27 = newActorShares == 0
            ? SafeCastI128.zero()
            : self.valuePerShareD27;
    }

    function _getActorValueChange(
        Data storage self,
        DistributionActor.Data storage actor
    ) private view returns (int256 valueChangeD18) {
        int256 deltaValuePerShareD27 = self.valuePerShareD27 - actor.lastValuePerShareD27;

        int256 changedValueD45 = deltaValuePerShareD27 * actor.sharesD18.toInt();
        valueChangeD18 = changedValueD45 / DecimalMath.UNIT_PRECISE_INT;
    }
}
