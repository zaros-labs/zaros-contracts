// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { CustomReferralConfiguration } from "@zaros/perpetuals/leaves/CustomReferralConfiguration.sol";

library Referral {
    /// @notice ERC7201 storage location.
    bytes32 internal constant REFERRAL_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.perpetuals.Referral")) - 1)) & ~bytes32(uint256(0xff));

    /// @notice {Referral} namespace storage structure.
    /// @param referralCode ABI encoded referral code, may be a string or address.
    /// @param isCustomReferralCode True if the referral code is a custom referral code.
    struct Data {
        bytes referralCode;
        bool isCustomReferralCode;
    }

    /// @notice Loads a {Referral}.
    /// @param tradingAccountId The trading account ID.
    /// @dev The referral object is linked to all trading accounts created by the accountOwner.
    /// @return referral The user referral data.
    function load(uint128 tradingAccountId) internal pure returns (Data storage referral) {
        bytes32 slot = keccak256(abi.encode(REFERRAL_LOCATION, tradingAccountId));
        assembly {
            referral.slot := slot
        }
    }

    /// @notice Returns the address of the referrer according to the referral code.
    /// @return referrer The referrer address.
    function getReferrerAddress(Data storage self) internal view returns (address referrer) {
        if (!self.isCustomReferralCode) {
            referrer = abi.decode(self.referralCode, (address));
        } else {
            referrer = CustomReferralConfiguration.load(string(self.referralCode)).referrer;
        }
    }
}
