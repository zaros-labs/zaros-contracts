// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IGlobalConfigurationModule } from "@zaros/markets/perps/interfaces/IGlobalConfigurationModule.sol";

interface IGlobalConfigurationModuleTestnet is IGlobalConfigurationModule {
    event LogCreateCustomReferralCode(address indexed referrer, string customReferralCode);

    function setUserPoints(address user, uint256 value) external;

    function createCustomReferralCode(address referrer, string memory customReferralCode) external;
}
