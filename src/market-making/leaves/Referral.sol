// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { CustomReferralConfiguration } from "@zaros/utils/leaves/CustomReferralConfiguration.sol";

// TODO: unify Referral logic at the protocol level, at `src/utils/leaves/Referral.sol`.
library Referral {
    /// @notice ERC7201 storage location.
    bytes32 internal constant REFERRAL_LOCATION =
        keccak256(abi.encode(uint256(keccak256("fi.zaros.market-making.Referral")) - 1)) & ~bytes32(uint256(0xff));

    /// @notice {Referral} namespace storage structure.
    /// @param referralCode ABI encoded referral code, may be a string or address.
    /// @param isCustomReferralCode True if the referral code is a custom referral code.
    struct Data {
        bytes referralCode;
        bool isCustomReferralCode;
    }

    /// @notice Loads a {Referral}.
    /// @param accountOwner The owner of the referred liquidity provider.
    /// @return referral The user referral data.
    function load(address accountOwner) internal pure returns (Data storage referral) {
        bytes32 slot = keccak256(abi.encode(REFERRAL_LOCATION, accountOwner));
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
