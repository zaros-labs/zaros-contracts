// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketMakingEngineConfigurationBranch } from
    "@zaros/market-making/branches/MarketMakingEngineConfigurationBranch.sol";

contract MarketMakingEngineConfigurationBranch_updateVault_Test is Base_Test {
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
        createVault();
        changePrank({ msgSender: users.owner.account });
    }

    modifier givenAVaultIsToBeUpdate() {
        _;
    }

    function test_RevertWhen_TheDepositCapIsZero() external givenAVaultIsToBeUpdate {
        Vault.UpdateParams memory params = Vault.UpdateParams({
            vaultId: VAULT_ID,
            depositCap: 0,
            withdrawalDelay: VAULT_WITHDRAW_DELAY,
            collateral: collateralData
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "depositCap"));
        marketMakingEngine.updateVaultConfiguration(params);
    }

    function test_RevertWhen_WithdrawalDelayIsZero() external givenAVaultIsToBeUpdate {
        Vault.UpdateParams memory params = Vault.UpdateParams({
            vaultId: VAULT_ID,
            depositCap: VAULT_DEPOSIT_CAP,
            withdrawalDelay: 0,
            collateral: collateralData
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "withdrawDelay"));
        marketMakingEngine.updateVaultConfiguration(params);
    }

    function test_RevertWhen_VaultIdIsZero() external givenAVaultIsToBeUpdate {
        Vault.UpdateParams memory params = Vault.UpdateParams({
            vaultId: 0,
            depositCap: VAULT_DEPOSIT_CAP,
            withdrawalDelay: VAULT_WITHDRAW_DELAY,
            collateral: collateralData
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "vaultId"));
        marketMakingEngine.updateVaultConfiguration(params);
    }

    function test_WhenAreValidParams() external givenAVaultIsToBeUpdate {
        uint128 updatedDepositCap = VAULT_DEPOSIT_CAP * 2;
        uint128 updatedWithdrawDelay = VAULT_DEPOSIT_CAP * 2;

        Vault.UpdateParams memory params = Vault.UpdateParams({
            vaultId: VAULT_ID,
            depositCap: updatedDepositCap,
            withdrawalDelay: updatedWithdrawDelay,
            collateral: collateralData
        });

        // it should emit update event
        vm.expectEmit();
        emit MarketMakingEngineConfigurationBranch.LogUpdateVaultConfiguration(users.owner.account, VAULT_ID);
        marketMakingEngine.updateVaultConfiguration(params);

        // it should update vault
        assertEq(updatedDepositCap, marketMakingEngine.workaround_Vault_getDepositCap(VAULT_ID));
        assertEq(updatedWithdrawDelay, marketMakingEngine.workaround_Vault_getWithdrawDelay(VAULT_ID));
    }
}
