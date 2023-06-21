//SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/**
 * @title Stores information about a deposited asset for a given account.
 *
 * Each account will have one of these objects for each type of collateral it deposited in the system.
 */
library Collateral {
    using EnumerableSet for EnumerableSet.UintSet;

    struct Data {
        /**
         * @dev The amount that can be withdrawn or delegated in this collateral.
         */
        uint256 amountAvailableForDelegation;
    }

    /**
     * @dev Increments the entry's availableCollateral.
     */
    function increaseAvailableCollateral(Data storage self, UD60x18 amount) internal {
        self.amountAvailableForDelegation = ud60x18(self.amountAvailableForDelegation).add(amount).intoUint256();
    }

    /**
     * @dev Decrements the entry's availableCollateral.
     */
    function decreaseAvailableCollateral(Data storage self, UD60x18 amount) internal {
        self.amountAvailableForDelegation = ud60x18(self.amountAvailableForDelegation).sub(amount).intoUint256();
    }
}
