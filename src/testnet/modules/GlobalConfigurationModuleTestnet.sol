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

    // address internal constant USDC = 0x50100D8227f0840DeA0a0cD2B85075685d62F42e;
    address internal constant USDZ = 0xdf99E26eF552027d65469e41fd56fEdAD6Cc2807;

    function setUserPoints(address user, uint256 value) external onlyOwner {
        Points.load(user).amount = value;
    }

    function createCustomReferralCode(address referrer, string memory customReferralCode) external onlyOwner {
        CustomReferralConfigurationTestnet.load(customReferralCode).referrer = referrer;

        emit LogCreateCustomReferralCode(referrer, customReferralCode);
    }

    function upgradeTokens() external onlyOwner {
        // LimitedMintingERC20 usdc = LimitedMintingERC20(USDC);
        LimitedMintingERC20 usdz = LimitedMintingERC20(USDZ);

        address newImplementation = address(new LimitedMintingERC20());

        // UUPSUpgradeable(address(usdc)).upgradeToAndCall(newImplementation, bytes(""));
        UUPSUpgradeable(address(usdz)).upgradeToAndCall(newImplementation, bytes(""));
    }
}
