// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { BaseScript } from "../Base.s.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";

// Forge dependencies
import { console } from "forge-std/console.sol";

/// @dev This script creates a list of custom referral codes for a list of referrers
contract CreateListOfCustomReferrals is BaseScript {
    IPerpsEngine internal perpsEngine;

    function run() public broadcaster {
        perpsEngine = IPerpsEngine(vm.envAddress("PERPS_ENGINE"));

        address[] memory referrers = new address[](3);

        referrers[0] = address(0x123);
        referrers[1] = address(0x456);
        referrers[2] = address(0x789);

        string[] memory customReferralCodes = new string[](3);

        customReferralCodes[0] = "ref1";
        customReferralCodes[1] = "ref2";
        customReferralCodes[2] = "ref3";

        for (uint256 i; i < referrers.length; i++) {
            perpsEngine.createCustomReferralCode(referrers[i], customReferralCodes[i]);
        }

        console.log("Custom referral codes created successfully");
    }
}
