// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { CustomReferralConfigurationTestnet } from "./CustomReferralConfigurationTestnet.sol";


library ReferralTestnet {
    string internal constant REFERRAL_TESTNET_DOMAIN = "fi.zaros.ReferralTestnet";

    struct Data {
        bytes referralCode;
        bool isCustomReferralCode;
    }

    function load(address accountOwner) internal pure returns (Data storage referralTestnet) {
        bytes32 slot = keccak256(abi.encode(REFERRAL_TESTNET_DOMAIN, accountOwner));

        assembly {
            referralTestnet.slot := slot
        }
    }

    function getReferrerAddress(Data storage self) internal view returns (address) {
        if (!self.isCustomReferralCode) {
            return abi.decode(self.referralCode, (address));
        } else {
            CustomReferralConfigurationTestnet.load(abi.decode(self.referralCode, (string))).referrer;
        }
    }
}

