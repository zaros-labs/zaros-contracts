// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract ClaimFees_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: address(users.owner.account) });
        configureMarketsDebt();
    }

    function testFuzz_RevertWhen_TheUserDoesNotHaveAvailableShares() external {
        // it should revert
    }

    modifier whenTheUserDoesHaveAvailableShares() {
        _;
    }

    function testFuzz_RevertWhen_AmountToClaimIsZero() external whenTheUserDoesHaveAvailableShares {
        // it should revert
    }

    function testFuzz_WhenAmountToCalimIsGreaterThenZero() external whenTheUserDoesHaveAvailableShares {
        // it should update accumulate actor
        // it should transfer the fees to the sender
        // it should emit {LogClaimFees} event
    }
}
