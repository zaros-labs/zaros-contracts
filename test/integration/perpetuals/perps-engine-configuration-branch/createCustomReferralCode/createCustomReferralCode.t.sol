// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { PerpsEngineConfigurationBranch } from "@zaros/perpetuals/branches/PerpsEngineConfigurationBranch.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract CreateCustomReferralCode_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheOwner(
        address referrer,
        string memory customReferralCode
    )
        external
    {
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.naruto.account)
        });

        perpsEngine.createCustomReferralCode(referrer, customReferralCode);
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function testFuzz_WhenCreateCustomReferralCodeIsCalled(
        address referrer,
        string memory customReferralCode
    )
        external
        givenTheSenderIsTheOwner
    {
        changePrank({ msgSender: users.owner.account });

        // it should emit {LogCreateCustomReferralCode} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit PerpsEngineConfigurationBranch.LogCreateCustomReferralCode(referrer, customReferralCode);

        perpsEngine.createCustomReferralCode(referrer, customReferralCode);

        // it should the custom referral code and referrer on storage
        address referrerReceived = perpsEngine.getCustomReferralCodeReferrer(customReferralCode);
        assertEq(referrerReceived, referrer, "Referrer not set correctly");
    }
}
