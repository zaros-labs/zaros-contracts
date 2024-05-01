// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IGlobalConfigurationBranch } from "@zaros/perpetuals/interfaces/IGlobalConfigurationBranch.sol";

interface IGlobalConfigurationBranchTestnet is IGlobalConfigurationBranch {
    event LogCreateCustomReferralCode(address indexed referrer, string customReferralCode);

    function setUserPoints(address user, uint256 value) external;

    function createCustomReferralCode(address referrer, string memory customReferralCode) external;
}
