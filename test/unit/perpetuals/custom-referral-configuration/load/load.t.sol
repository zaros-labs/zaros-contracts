// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { CustomReferralConfiguration } from "@zaros/utils/leaves/CustomReferralConfiguration.sol";

contract CustomReferralConfiguration_Load_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_WhenLoadIsCalled() external {
        changePrank({ msgSender: users.owner.account });

        string memory customReferralCode = "Madara Uchiha";

        perpsEngine.createCustomReferralCode(users.madara.account, customReferralCode);

        CustomReferralConfiguration.Data memory customReferralConfiguration =
            perpsEngine.exposed_CustomReferralConfiguration_load(customReferralCode);

        // it should return the referrer
        assertEq(customReferralConfiguration.referrer, users.madara.account, "the address of referrer is not correct");
    }
}
