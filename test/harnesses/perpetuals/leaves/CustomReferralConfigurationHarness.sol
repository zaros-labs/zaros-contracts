// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { CustomReferralConfiguration } from "@zaros/utils/leaves/CustomReferralConfiguration.sol";

contract CustomReferralConfigurationHarness {
    function exposed_CustomReferralConfiguration_load(string memory customReferralCode)
        external
        pure
        returns (CustomReferralConfiguration.Data memory)
    {
        return CustomReferralConfiguration.load(customReferralCode);
    }
}
