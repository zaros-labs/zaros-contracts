// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract MarketMaking_stake_Test is Base_Test {

    function setUp() public virtual override {
        Base_Test.setUp();
        createVault();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_VaultIsInvalid() external {
        // it should revert
    }

    function test_WhenUserHasShares() external {
        // it should update staked shares
    }

    modifier whenTheUserHasAReferralCode() {
        _;
    }

    modifier whenTheReferralCodeIsCustom() {
        _;
    }

    function test_RevertWhen_TheReferralCodeIsInvalid()
        external
        whenTheUserHasAReferralCode
        whenTheReferralCodeIsCustom
    {
        // it should revert
    }

    function test_WhenTheReferralCodeIsValid() external whenTheUserHasAReferralCode whenTheReferralCodeIsCustom {
        // it should emit {LogReferralSet} event
    }

    modifier whenTheReferralCodeIsNotCustom() {
        _;
    }

    function test_RevertWhen_TheReferralCodeIsEqualToMsgSender()
        external
        whenTheUserHasAReferralCode
        whenTheReferralCodeIsNotCustom
    {
        // it should revert
    }

    function test_WhenTheReferralCodeIsNotEqualToMsgSender()
        external
        whenTheUserHasAReferralCode
        whenTheReferralCodeIsNotCustom
    {
        // it should emit {LogReferralSet} event
    }
}
