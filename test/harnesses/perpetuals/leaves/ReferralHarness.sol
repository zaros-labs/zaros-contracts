// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Referral } from "@zaros/perpetuals/leaves/Referral.sol";

contract ReferralHarness {
    function exposed_Referral_load(address accountOwner) external pure returns (Referral.Data memory) {
        return Referral.load(accountOwner);
    }

    function exposed_Referral_getReferrerAddress(address accountOwner) external view returns (address) {
        Referral.Data storage self = Referral.load(accountOwner);

        return Referral.getReferrerAddress(self);
    }
}
