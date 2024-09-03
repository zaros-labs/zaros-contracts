// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Errors } from "@zaros/utils/Errors.sol";

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
    function initialize(address usdToken, address perpsEngine, address owner) external initializer {
        __Ownable_init(owner);
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        marketMakingEngineConfiguration.usdz = usdz;
        marketMakingEngineConfiguration.perpsEngine = perpsEngine;
    }

    /// @notice Returns the address of custom referral code
    /// @param customReferralCode The custom referral code.
    /// @return referrer The address of the referrer.
    function getCustomReferralCodeReferrer(string memory customReferralCode) external view returns (address) { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function configureSystemParameters() external onlyOwner { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function configureSequencerUptimeFeed() external onlyOwner { }

    /// @dev Invariants involved in the call:
    /// TODO: add invariants
    function createCustomReferralCode() external onlyOwner { }

    /// @dev Invariants involved in the call:
    /// Must NOT be able to create a vault with id set to 0
    function createVault(Vault.CreateParams calldata params) external onlyOwner {
        if (params.indexToken == address(0)) {
            revert Errors.ZeroInput("indexToken");
        }

        if (params.depositCap == 0) {
            revert Errors.ZeroInput("depositCap");
        }

        if (params.withdrawalDelay == 0) {
            revert Errors.ZeroInput("withdrawDelay");
        }

        if (params.vaultId == 0) {
            revert Errors.ZeroInput("vaultId");
        }

        Vault.create(params);
    }

    /// @dev Invariants involved in the call:
    /// Must NOT be able to update vault with id set to 0
    function updateVaultConfiguration(Vault.UpdateParams calldata params) external onlyOwner {
        if (params.depositCap == 0) {
            revert Errors.ZeroInput("depositCap");
        }

        if (params.withdrawalDelay == 0) {
            revert Errors.ZeroInput("withdrawDelay");
        }

        if (params.vaultId == 0) {
            revert Errors.ZeroInput("vaultId");
        }

        Vault.update(params);
    }
}
