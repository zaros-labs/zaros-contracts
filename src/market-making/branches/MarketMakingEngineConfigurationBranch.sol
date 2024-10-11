// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";

// Open Zeppelin Upgradeable dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// TODO: add initializer at upgrade branch or auth branch
contract MarketMakingEngineConfigurationBranch is OwnableUpgradeable {
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;

    /// @notice Emitted when an engine is registered.
    /// @param engine The address of the engine contract.
    event LogRegisterEngine(address engine);

    /// @notice Emitted when the USD Token address is set or updated.
    /// @param usdToken The address of the USD Token token.
    event LogSetUsdToken(address usdToken);

    /// @notice Returns the address of custom referral code
    /// @param customReferralCode The custom referral code.
    /// @return referrer The address of the referrer.
    function getCustomReferralCodeReferrer(string memory customReferralCode) external view returns (address) { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function configureSystemParameters() external onlyOwner { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function createCustomReferralCode() external onlyOwner { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function createVault() external onlyOwner { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function updateVaultConfiguration() external onlyOwner { }

    function registerEngine(address engine) external onlyOwner {
        if (engine == address(0)) revert Errors.ZeroInput("engine");

        MarketMakingEngineConfiguration.load().registeredEngines[engine] = true;

        emit LogRegisterEngine(engine);
    }

    function setUsdToken(address usdToken) external onlyOwner {
        if (usdToken == address(0)) revert Errors.ZeroInput("usdToken");

        MarketMakingEngineConfiguration.load().usdToken = usdToken;

        emit LogSetUsdToken(usdToken);
    }
}
