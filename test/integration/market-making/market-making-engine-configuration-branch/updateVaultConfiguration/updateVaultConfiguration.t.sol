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

contract UpdateVaultConfiguration_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
    }

    function testFuzz_RevertWhen_TheDepositCapIsZero(uint256 vaultId) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        Collateral.Data memory collateralData = Collateral.Data({
            creditRatio: fuzzVaultConfig.creditRatio,
            priceFeedHeartbeatSeconds: fuzzVaultConfig.priceFeedHeartbeatSeconds,
            priceAdapter: fuzzVaultConfig.priceAdapter,
            asset: fuzzVaultConfig.asset,
            isEnabled: fuzzVaultConfig.isEnabled,
            decimals: fuzzVaultConfig.decimals
        });

        Vault.UpdateParams memory params = Vault.UpdateParams({
            vaultId: fuzzVaultConfig.vaultId,
            depositCap: 0,
            withdrawalDelay: fuzzVaultConfig.withdrawalDelay,
            collateral: collateralData
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "depositCap"));
        marketMakingEngine.updateVaultConfiguration(params);
    }

    function testFuzz_RevertWhen_WithdrawalDelayIsZero(uint256 vaultId) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        Collateral.Data memory collateralData = Collateral.Data({
            creditRatio: fuzzVaultConfig.creditRatio,
            priceFeedHeartbeatSeconds: fuzzVaultConfig.priceFeedHeartbeatSeconds,
            priceAdapter: fuzzVaultConfig.priceAdapter,
            asset: fuzzVaultConfig.asset,
            isEnabled: fuzzVaultConfig.isEnabled,
            decimals: fuzzVaultConfig.decimals
        });

        Vault.UpdateParams memory params = Vault.UpdateParams({
            vaultId: fuzzVaultConfig.vaultId,
            depositCap: fuzzVaultConfig.depositCap,
            withdrawalDelay: 0,
            collateral: collateralData
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "withdrawDelay"));
        marketMakingEngine.updateVaultConfiguration(params);
    }

    function testFuzz_RevertWhen_VaultIdIsZero(uint256 vaultId, uint256 depositCap, uint256 withdrawDelay) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        Collateral.Data memory collateralData = Collateral.Data({
            creditRatio: fuzzVaultConfig.creditRatio,
            priceFeedHeartbeatSeconds: fuzzVaultConfig.priceFeedHeartbeatSeconds,
            priceAdapter: fuzzVaultConfig.priceAdapter,
            asset: fuzzVaultConfig.asset,
            isEnabled: fuzzVaultConfig.isEnabled,
            decimals: fuzzVaultConfig.decimals
        });

        depositCap = bound({ x: depositCap, min: 1, max: type(uint128).max });
        withdrawDelay = bound({ x: withdrawDelay, min: 1, max: type(uint128).max });

        Vault.UpdateParams memory params = Vault.UpdateParams({
            vaultId: 0,
            depositCap: uint128(depositCap),
            withdrawalDelay: uint128(withdrawDelay),
            collateral: collateralData
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "vaultId"));
        marketMakingEngine.updateVaultConfiguration(params);
    }

    function testFuzz_WhenAreValidParams(
        uint256 vaultId,
        uint256 updatedDepositCap,
        uint256 updatedWithdrawDelay
    )
        external
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        Collateral.Data memory collateralData = Collateral.Data({
            creditRatio: fuzzVaultConfig.creditRatio,
            priceFeedHeartbeatSeconds: fuzzVaultConfig.priceFeedHeartbeatSeconds,
            priceAdapter: fuzzVaultConfig.priceAdapter,
            asset: fuzzVaultConfig.asset,
            isEnabled: fuzzVaultConfig.isEnabled,
            decimals: fuzzVaultConfig.decimals
        });

        updatedDepositCap = bound({ x: updatedDepositCap, min: 1, max: type(uint128).max });
        updatedWithdrawDelay = bound({ x: updatedWithdrawDelay, min: 1, max: type(uint128).max });

        Vault.UpdateParams memory params = Vault.UpdateParams({
            vaultId: fuzzVaultConfig.vaultId,
            depositCap: uint128(updatedDepositCap),
            withdrawalDelay: uint128(updatedWithdrawDelay),
            collateral: collateralData
        });

        // it should emit update event
        vm.expectEmit();
        emit MarketMakingEngineConfigurationBranch.LogUpdateVaultConfiguration(
            users.owner.account, fuzzVaultConfig.vaultId
        );
        marketMakingEngine.updateVaultConfiguration(params);

        // it should update vault
        assertEq(updatedDepositCap, marketMakingEngine.workaround_Vault_getDepositCap(fuzzVaultConfig.vaultId));
        assertEq(updatedWithdrawDelay, marketMakingEngine.workaround_Vault_getWithdrawDelay(fuzzVaultConfig.vaultId));
    }
}
