// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Referral } from "@zaros/perpetuals/leaves/Referral.sol";

contract ReferralHarness {
    function exposed_Referral_load(uint128 tradingAccountId) external pure returns (Referral.Data memory) {
        return Referral.load(tradingAccountId);
    }

    function exposed_Referral_getReferrerAddress(uint128 tradingAccountId) external view returns (address) {
        Referral.Data storage self = Referral.load(tradingAccountId);

        return Referral.getReferrerAddress(self);
    }
}
