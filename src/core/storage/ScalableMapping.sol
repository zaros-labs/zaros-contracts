//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, UNIT as SD_UNIT, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

/**
 * @title Data structure that wraps a mapping with a scalar multiplier.
 *
 * If you wanted to modify all the values in a mapping by the same amount, you would normally have to loop through each
 * entry in the mapping. This object allows you to modify all of them at once, by simply modifying the scalar
 * multiplier.
 *
 * I.e. a regular mapping represents values like this:
 * value = mapping[id]
 *
 * And a scalable mapping represents values like this:
 * value = mapping[id] * scalar
 *
 * This reduces the number of computations needed for modifying the balances of N users from O(n) to O(1).
 *
 * Note: Notice how users are tracked by a generic bytes32 id instead of an address. This allows the actors of the
 * mapping not just to be addresses. They can be anything, for example a pool id, an account id, etc.
 *
 * *********************
 * Conceptual Examples
 * *********************
 *
 * 1) Socialization of collateral during a liquidation.
 *
 * Scalable mappings are very useful for "socialization" of collateral, that is, the re-distribution of collateral when
 * an account is liquidated. Suppose 1000 ETH are liquidated, and would need to be distributed amongst 1000 depositors.
 * With a regular mapping, every depositor's balance would have to be modified in a loop that iterates through every
 * single one of them. With a scalable mapping, the scalar would simply need to be incremented so that the total value
 * of the mapping increases by 1000 ETH.
 *
 * 2) Socialization of debt during a liquidation.
 *
 * Similar to the socialization of collateral during a liquidation, the debt of the position that is being liquidated
 * can be re-allocated using a scalable mapping with a single action. Supposing a scalable mapping tracks each user's
 * debt in the system, and that 1000 sUSD has to be distributed amongst 1000 depositors, the debt data structure's
 * scalar would simply need to be incremented so that the total value or debt of the distribution increments by 1000
 * sUSD.
 *
 */
library ScalableMapping {
    using SafeCast for int256;

    /**
     * @dev Thrown when attempting to scale a mapping with an amount that is lower than its resolution.
     */
    error Zaros_ScalableMapping_InsufficientMappedAmount();

    /**
     * @dev Thrown when attempting to scale a mapping with no shares.
     */
    error Zaros_ScalableMapping_CannotScaleEmptyMapping();

    struct Data {
        uint128 totalShares;
        int128 scaleModifier;
        mapping(bytes32 => uint256) shares;
    }

    /**
     * @dev Inflates or deflates the total value of the distribution by the given value.
     * @dev The incoming value is split per share, and used as a delta that is *added* to the existing scale modifier.
     * The resulting scale modifier must be in the range [-1, type(int128).max).
     */
    function scale(Data storage self, SD59x18 value) internal {
        if (value.isZero()) {
            return;
        }

        UD60x18 totalShares = ud60x18(self.totalShares);
        if (totalShares.isZero()) {
            revert Zaros_ScalableMapping_CannotScaleEmptyMapping();
        }

        SD59x18 deltaScaleModifier = value.div(totalShares.intoSD59x18());
        SD59x18 newScaleModifier = sd59x18(self.scaleModifier).add(deltaScaleModifier);

        if (newScaleModifier.lt(-SD_UNIT)) {
            revert Zaros_ScalableMapping_InsufficientMappedAmount();
        }

        self.scaleModifier = newScaleModifier.intoInt256().toInt128();
    }

    /**
     * @dev Updates an actor's individual value in the distribution to the specified amount.
     *
     * The change in value is manifested in the distribution by changing the actor's number of shares in it, and thus
     * the distribution's total number of shares.
     *
     * Returns the resulting amount of shares that the actor has after this change in value.
     */
    function set(
        Data storage self,
        bytes32 actorId,
        UD60x18 newActorValue
    )
        internal
        returns (UD60x18 resultingShares)
    {
        // Represent the actor's change in value by changing the actor's number of shares,
        // and keeping the distribution's scaleModifier constant.

        resultingShares = getSharesForAmount(self, newActorValue);

        // Modify the total shares with the actor's change in shares.
        self.totalShares =
            (ud60x18(self.totalShares).add(resultingShares).sub(ud60x18(self.shares[actorId]))).intoUint128();
        self.shares[actorId] = resultingShares.intoUint128();
    }

    /**
     * @dev Returns the value owned by the actor in the distribution.
     *
     * i.e. actor.shares * scaleModifier
     */
    function get(Data storage self, bytes32 actorId) internal view returns (UD60x18 value) {
        UD60x18 totalShares = ud60x18(self.totalShares);
        UD60x18 actorShares = ud60x18(self.shares[actorId]);
        if (totalShares.isZero()) {
            return UD_ZERO;
        }

        return (actorShares.mul(totalAmount(self))).div(totalShares);
    }

    /**
     * @dev Returns the total value held in the distribution.
     *
     * i.e. totalShares * scaleModifier
     */
    function totalAmount(Data storage self) internal view returns (UD60x18 value) {
        return sd59x18((self.scaleModifier)).add(SD_UNIT).intoUD60x18().mul(ud60x18(self.totalShares));
    }

    function getSharesForAmount(Data storage self, UD60x18 amount) internal view returns (UD60x18 shares) {
        shares = amount.div(sd59x18(self.scaleModifier).add(SD_UNIT).intoUD60x18());
    }
}
