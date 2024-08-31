// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract MarketMaking_redeem_Test is Base_Test {

    function setUp() public virtual override {
        Base_Test.setUp();
        createVault();
        changePrank({ msgSender: users.naruto.account });
    }

    modifier whenRedeemIsCalled() {
        _;
    }

    function test_WhenDelayHasPassed() external whenRedeemIsCalled {
        // it should transfer assets to user
    }

    function test_RevertWhen_DelayHasNotPassed() external whenRedeemIsCalled {
        // it should revert
    }

    function test_RevertWhen_AssetsAreLessThenMinAmount() external whenRedeemIsCalled {
        // it should revert
    }

    function test_RevertWhen_RequiestIsNotFulfulled() external whenRedeemIsCalled {
        // it should revert
    }
}
