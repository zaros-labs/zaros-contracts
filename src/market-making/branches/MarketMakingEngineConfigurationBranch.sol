// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfiguration } from "@zaros/market-making/leaves/MarketMakingEngineConfiguration.sol";
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { MarketDebt } from "src/market-making/leaves/MarketDebt.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { SwapRouter } from "@zaros/market-making/leaves/SwapRouter.sol";

// Open Zeppelin Upgradeable dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

// TODO: add initializer at upgrade branch or auth branch
contract MarketMakingEngineConfigurationBranch is OwnableUpgradeable {
    using MarketMakingEngineConfiguration for MarketMakingEngineConfiguration.Data;

    /// @notice Emitted when an engine is registered.
    /// @param engine The address of the engine contract.
    event LogRegisterEngine(address engine);

    /// @notice Emitted when a new vault is created.
    /// @param sender The address that created the vault.
    /// @param vaultId The vault id.
    event LogCreateVault(address indexed sender, uint128 vaultId);

    /// @notice Emitted when a vault is updated.
    /// @param sender The address that updated the vault.
    /// @param vaultId The vault id.
    event LogUpdateVaultConfiguration(address indexed sender, uint128 vaultId);

    /// @notice Emitted when an engine's configuration is updated.
    /// @param engine The address of the engine contract.
    /// @param usdToken The address of the USD token contract.
    /// @param shouldBeEnabled A flag indicating whether the engine should be enabled or disabled.
    event LogConfigureEngine(address engine, address usdToken, bool shouldBeEnabled);

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

        emit LogCreateVault(msg.sender, params.vaultId);
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

        emit LogUpdateVaultConfiguration(msg.sender, params.vaultId);
    }

<<<<<<< HEAD
    function updateVaultConnectedMarkets(uint128 vaultId, uint128[] calldata marketsIds) external onlyOwner {
        // if (vaultId == 0) {
        //     revert Errors.ZeroInput("vaultId");
        // }

        // if (marketsIds.length == 0) {
        //     revert Errors.ZeroInput("connectedMarketsIds");
        // }

        // Vault.Data storage vault = Vault.load(vaultId);

        // vault.
    }

    /// @notice Configures an engine contract and sets its linked USD token address.
    /// @dev This function can be used to enable or disable an active engine contract.
    /// @param engine The address of the engine contract.
    /// @param usdToken The address of the USD token contract.
    /// @param shouldBeEnabled A flag indicating whether the engine should be enabled.
    function configureEngine(address engine, address usdToken, bool shouldBeEnabled) external onlyOwner {
        if (engine == address(0)) revert Errors.ZeroInput("engine");

        // loads the mm engine config storage pointer
        MarketMakingEngineConfiguration.Data storage marketMakingEngineConfiguration =
            MarketMakingEngineConfiguration.load();

        // if the engine needs to be disabled, set the isRegisteredEngine flag to false
        if (!shouldBeEnabled) {
            marketMakingEngineConfiguration.isRegisteredEngine[engine] = false;
            // sets the engine's usd token address to zero
            marketMakingEngineConfiguration.usdTokenOfEngine[engine] = address(0);

            emit LogConfigureEngine(engine, address(0), shouldBeEnabled);

            return;
        }

        // if the engine should be registered or the usd token updated, it mustn't be the zero address
        if (usdToken == address(0)) revert Errors.ZeroInput("usdToken");

        // registers the given engine if not already registered
        if (!marketMakingEngineConfiguration.isRegisteredEngine[engine]) {
            marketMakingEngineConfiguration.isRegisteredEngine[engine] = true;
        }

        // sets the USD token address of the given engine
        marketMakingEngineConfiguration.usdTokenOfEngine[engine] = usdToken;

        emit LogConfigureEngine(engine, usdToken, shouldBeEnabled);
    }
}
