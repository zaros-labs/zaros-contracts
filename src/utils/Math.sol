// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// PRB Math dependencies
import { SD59x18, sd59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

library Math {
    function divUp(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
        return a.mod(b) == SD_ZERO ? a.div(b) : a.div(b).add(sd59x18(1));
    }

    function max(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
        return a.gt(b) ? a : b;
    }

    function min(SD59x18 a, SD59x18 b) internal pure returns (SD59x18) {
        return a.lt(b) ? a : b;
    }
}
