// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { GlobalConfigurationModule } from "@zaros/markets/perps/modules/GlobalConfigurationModule.sol";
import { CustomReferralConfigurationTestnet } from "../storage/CustomReferralConfigurationTestnet.sol";
import { Points } from "../storage/Points.sol";

import { LimitedMintingERC20 } from "@zaros/testnet/LimitedMintingERC20.sol";

// Open Zeppelin dependencies
import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";

contract GlobalConfigurationModuleTestnet is GlobalConfigurationModule {
    event LogCreateCustomReferralCode(address indexed referrer, string customReferralCode);

    function getCustomReferralCodeReferrer(string memory customReferralCode) external view returns (address) {
        return CustomReferralConfigurationTestnet.load(customReferralCode).referrer;
    }

    function setUserPoints(address user, uint256 value) external onlyOwner {
        Points.load(user).amount = value;
    }

    function createCustomReferralCode(address referrer, string memory customReferralCode) external onlyOwner {
        CustomReferralConfigurationTestnet.load(customReferralCode).referrer = referrer;

        emit LogCreateCustomReferralCode(referrer, customReferralCode);
    }
}
