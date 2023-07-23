//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

library Collateral {
    using EnumerableSet for EnumerableSet.UintSet;

    struct Data {
        uint256 amountAvailableForDelegation;
    }

    function increaseAvailableCollateral(Data storage self, UD60x18 amount) internal {
        self.amountAvailableForDelegation = ud60x18(self.amountAvailableForDelegation).add(amount).intoUint256();
    }

    function decreaseAvailableCollateral(Data storage self, UD60x18 amount) internal {
        self.amountAvailableForDelegation = ud60x18(self.amountAvailableForDelegation).sub(amount).intoUint256();
    }
}
