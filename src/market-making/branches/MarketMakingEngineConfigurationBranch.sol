// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";

// Open Zeppelin Upgradeable dependencies
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

contract MarketMakingEngineConfigurationBranch is Initializable, OwnableUpgradeable {
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;

    constructor() {
        _disableInitializers();
    }

    /// @dev The Ownable contract is initialized at the UpgradeBranch.
    /// @dev {MarketMakingEngineConfigurationBranch} UUPS initializer.
    function initialize(address usdToken, address perpsEngine) external initializer {
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        marketMakingEngineConfiguration.usdToken = usdToken;
        marketMakingEngineConfiguration.perpsEngine = perpsEngine;
    }

    /// @notice Returns the address of custom referral code
    /// @param customReferralCode The custom referral code.
    /// @return referrer The address of the referrer.
    function getCustomReferralCodeReferrer(string memory customReferralCode) external view returns (address) { }

    function configureSystemParameters() external onlyOwner { }

    function configureSequencerUptimeFeed() external onlyOwner { }

    function createCustomReferralCode() external onlyOwner { }

    function createVault() external onlyOwner { }

    function updateVaultConfiguration() external onlyOwner { }
}
