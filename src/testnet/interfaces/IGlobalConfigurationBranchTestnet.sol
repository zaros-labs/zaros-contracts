// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";

abstract contract IGlobalConfigurationBranchTestnet is GlobalConfigurationBranch {
    event LogCreateCustomReferralCode(address indexed referrer, string customReferralCode);

    function setUserPoints(address user, uint256 value) virtual external;

    function createCustomReferralCode(address referrer, string memory customReferralCode) virtual external;
}
