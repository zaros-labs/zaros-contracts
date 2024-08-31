// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract MarketMaking_unstake_Test is Base_Test{
    function test_RevertWhen_UserDoesNotHaveEnoguhtStakedShares() external {
        // it should revert
    }

    function test_WhenUserHasStakedShares() external {
        // it should log unstake event
    }
}
