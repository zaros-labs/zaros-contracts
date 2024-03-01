// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;


library ReferralTestnet {
    string internal constant REFERRAL_TESTNET_DOMAIN = "fi.zaros.ReferralTestnet";

    struct Data {
        address accountOwner;
        bytes referralCode;
        bool isCustomReferralCode;
    }

    function load(address user) internal pure returns (Data storage referralTestnet) {
        bytes32 slot = keccak256(abi.encode(POINTS_DOMAIN, user));

        assembly {
            referralTestnet.slot := slot
        }
    }

    function getReferrerAddress(Data storage self) internal view returns (address) {
        if (!self.isCustomReferralCode) {
            return abi.decode(self.referralCode, (address));
        } else {
            CustomReferralConfigurationTestnet.load(abi.decode(self.referralCode, (string memory)).referrer;
        }
    }
}

