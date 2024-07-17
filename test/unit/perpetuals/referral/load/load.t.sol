// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Referral } from "@zaros/perpetuals/leaves/Referral.sol";

contract Referral_Load_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
    }

    function test_WhenLoadIsCalled() external {
        changePrank({ msgSender: users.owner.account });

        perpsEngine.createTradingAccount(abi.encode(users.naruto.account), false);

        Referral.Data memory referral = perpsEngine.exposed_Referral_load(users.owner.account);

        // it should return the referral code
        assertEq(
            abi.decode(referral.referralCode, (address)), users.naruto.account, "the referral code is not correct"
        );

        // it should return if referral code is custom
        assertEq(referral.isCustomReferralCode, false, "the flag `isCustomReferralCode` should be false");

        string memory customReferralCode = "Madara Uchiha";
        bytes memory bytesReferralCode = bytes(customReferralCode);

        perpsEngine.createCustomReferralCode(users.madara.account, customReferralCode);

        changePrank({ msgSender: users.sakura.account });

        perpsEngine.createTradingAccount(bytesReferralCode, true);

        referral = perpsEngine.exposed_Referral_load(users.sakura.account);

        // it should return the referral code
        assertEq(referral.referralCode, bytesReferralCode, "the referral code is not correct");

        // it should return if referral code is custom
        assertEq(referral.isCustomReferralCode, true, "the flag `isCustomReferralCode` should be trye");
    }
}
