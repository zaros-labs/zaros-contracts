//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// PRB Math dependencies
import { UD60x18, ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, UNIT as SD_UNIT, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

library ScalableMapping {
    using SafeCast for int256;

    error Zaros_ScalableMapping_InsufficientMappedAmount();

    error Zaros_ScalableMapping_CannotScaleEmptyMapping();

    struct Data {
        uint128 totalShares;
        int128 scaleModifier;
        mapping(bytes32 actorId => uint256) shares;
    }

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

    function get(Data storage self, bytes32 actorId) internal view returns (UD60x18 value) {
        UD60x18 totalShares = ud60x18(self.totalShares);
        UD60x18 actorShares = ud60x18(self.shares[actorId]);
        if (totalShares.isZero()) {
            return UD_ZERO;
        }

        return (actorShares.mul(totalAmount(self))).div(totalShares);
    }

    function totalAmount(Data storage self) internal view returns (UD60x18 value) {
        return sd59x18((self.scaleModifier)).add(SD_UNIT).intoUD60x18().mul(ud60x18(self.totalShares));
    }

    function getSharesForAmount(Data storage self, UD60x18 amount) internal view returns (UD60x18 shares) {
        shares = amount.div(sd59x18(self.scaleModifier).add(SD_UNIT).intoUD60x18());
    }
}
