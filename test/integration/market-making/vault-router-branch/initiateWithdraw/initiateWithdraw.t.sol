// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract MarketMaking_initiateWithdraw_Test is Base_Test {

    function setUp() public virtual override {
        Base_Test.setUp();
        createVault();
        changePrank({ msgSender: users.naruto.account });
    }

    modifier whenInitiateWithdrawIsCalled() {
        _;
    }

    function test_RevertWhen_AmountIsZero() external whenInitiateWithdrawIsCalled {
        // it should revert
    }

    function test_RevertWhen_VaultIdIsInvalid() external whenInitiateWithdrawIsCalled {
        // it should revert
    }

    function test_RevertWhen_SharesAmountIsGtUserBalance() external whenInitiateWithdrawIsCalled {
        // it should revert
    }

    function test_WhenUserHasSharesBalance() external whenInitiateWithdrawIsCalled {
        // it should create withdraw request
    }
}
