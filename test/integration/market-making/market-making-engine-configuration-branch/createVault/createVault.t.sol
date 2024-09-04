// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";

contract MarketMakingEngineConfigurationBranch_createVault_Test is Base_Test {
    Collateral.Data collateralData = Collateral.Data({
        creditRatio: 1.5e18,
        priceFeedHeartbeatSeconds: 120,
        priceAdapter: address(0),
        asset: address(wEth),
        isEnabled: true,
        decimals: 8
    });

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
    }

    modifier givenAVaultIsToBeCreated() {
        _;
    }

    function test_RevertWhen_TheDepositIndexTokenAddressZero() external givenAVaultIsToBeCreated {
        Vault.CreateParams memory params = Vault.CreateParams({
            vaultId: VAULT_ID,
            depositCap: VAULT_DEPOSIT_CAP,
            withdrawalDelay: VAULT_WITHDRAW_DELAY,
            indexToken: address(0),
            collateral: collateralData
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "indexToken"));
        marketMakingEngine.createVault(params);
    }

    function test_RevertWhen_TheDepositCapIsZero() external givenAVaultIsToBeCreated {
        Vault.CreateParams memory params = Vault.CreateParams({
            vaultId: VAULT_ID,
            depositCap: 0,
            withdrawalDelay: VAULT_WITHDRAW_DELAY,
            indexToken: address(zlpVault),
            collateral: collateralData
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "depositCap"));
        marketMakingEngine.createVault(params);
    }

    function test_RevertWhen_WithdrawalDelayIsZero() external givenAVaultIsToBeCreated {
        Vault.CreateParams memory params = Vault.CreateParams({
            vaultId: VAULT_ID,
            depositCap: 2e18,
            withdrawalDelay: 0,
            indexToken: address(zlpVault),
            collateral: collateralData
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "withdrawDelay"));
        marketMakingEngine.createVault(params);
    }

    function test_RevertWhen_VaultIdIsZero() external givenAVaultIsToBeCreated {
        Vault.CreateParams memory params = Vault.CreateParams({
            vaultId: 0,
            depositCap: 1e18,
            withdrawalDelay: VAULT_WITHDRAW_DELAY,
            indexToken: address(zlpVault),
            collateral: collateralData
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "vaultId"));
        marketMakingEngine.createVault(params);
    }

    function test_RevertWhen_VaultWithThatIdAlreadyExists() external givenAVaultIsToBeCreated {
        createVault();
        Vault.CreateParams memory params = Vault.CreateParams({
            vaultId: VAULT_ID,
            depositCap: 2e18,
            withdrawalDelay: VAULT_WITHDRAW_DELAY,
            indexToken: address(zlpVault),
            collateral: collateralData
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.VaulttAlreadyEnabled.selector, VAULT_ID));
        marketMakingEngine.createVault(params);
    }

    function test_WhenVaultDoesNotExist() external givenAVaultIsToBeCreated {
        Vault.CreateParams memory params = Vault.CreateParams({
            vaultId: VAULT_ID,
            depositCap: 2e18,
            withdrawalDelay: VAULT_WITHDRAW_DELAY,
            indexToken: address(zlpVault),
            collateral: collateralData
        });

        // it should emit event
        vm.expectEmit();
        emit MarketMakingEngineConfigurationBranch.LogCreateVault(users.owner.account, VAULT_ID);
        marketMakingEngine.createVault(params);
        // it should create vault
        assertEq(address(zlpVault), marketMakingEngine.workaround_Vault_getIndexToken(VAULT_ID));
    }
}
