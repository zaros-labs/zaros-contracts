// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

library CustomReferralConfiguration {
    /// @notice ERC7201 storage location.
    bytes32 internal constant CUSTOM_REFERRAL_CONFIGURATION_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.perpetuals.CustomReferralConfiguration")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @notice {CustomReferralConfiguration} namespace storage structure.
    /// @param referrer The referrer address linked to the custom referral code.
    struct Data {
        address referrer;
    }

    /// @notice Loads a {CustomReferralConfiguration}.
    /// @param customReferralCode The custom referral code string.
    function load(string memory customReferralCode)
        internal
        pure
        returns (Data storage customReferralConfigurationTestnet)
    {
        bytes32 slot = keccak256(abi.encode(CUSTOM_REFERRAL_CONFIGURATION_LOCATION, customReferralCode));
        assembly {
            customReferralConfigurationTestnet.slot := slot
        }
    }
}
