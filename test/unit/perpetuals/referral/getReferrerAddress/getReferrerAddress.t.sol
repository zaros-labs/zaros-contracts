// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract GetReferrerAddress_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_WhenReferralCodeIsCustom() external {
        changePrank({ msgSender: users.owner.account });

        string memory customReferralCode = "Naruto Uzumaki";
        bytes memory bytesReferralCode = bytes(customReferralCode);

        perpsEngine.createCustomReferralCode(users.naruto.account, customReferralCode);

        uint128 tradingAccountId = perpsEngine.createTradingAccount(bytesReferralCode, true);

        address referrer = perpsEngine.exposed_Referral_getReferrerAddress(tradingAccountId);

        // it should return the address of referrer
        assertEq(referrer, users.naruto.account, "the referrer is not correct");
    }

    function test_WhenReferralCodeIsNotCustom() external {
        changePrank({ msgSender: users.owner.account });

        uint128 tradingAccountId = perpsEngine.createTradingAccount(abi.encode(users.naruto.account), false);

        address referrer = perpsEngine.exposed_Referral_getReferrerAddress(tradingAccountId);

        // it should return the address of referrer
        assertEq(referrer, users.naruto.account, "the referrer is not correct");
    }
}
