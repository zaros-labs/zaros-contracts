// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { GlobalConfigurationModule } from "@zaros/markets/perps/modules/GlobalConfigurationModule.sol";
import { CustomReferralConfigurationTestnet } from "./CustomReferralConfigurationTestnet.sol";
import { Points } from "../storage/Points.sol";


contract GlobalConfigurationModuleTestnet is GlobalConfigurationModule {
    event LogCreateCustomReferralCode(address indexed referrer, string customReferralCode);

    function setUserPoints(address user, uint256 value) external onlyOwner {
        Points.load(user).amount = value;
    }

    function createCustomReferralCode(address referrer, string memory customReferralCode) external onlyOwner {
        CustomReferralConfigurationTestnet.load(customReferralCode).referrer = referrer;

        emit LogCreateCustomReferralCode(referrer, customReferralCode);
    }
}
