// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { Vault } from "@zaros/market-making/leaves/Vault.sol";
import { Collateral } from "@zaros/market-making/leaves/Collateral.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract Vault_Create_Unit_Test is Base_Test {
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

    function test_RevertWhen_CreateIsPassedExistingMarketId() external {
        createVault();
        Vault.CreateParams memory params = Vault.CreateParams({
            vaultId: VAULT_ID,
            depositCap: VAULT_DEPOSIT_CAP,
            withdrawalDelay: VAULT_WITHDRAW_DELAY,
            indexToken: address(zlpVault),
            collateral: collateralData
        });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.VaulttAlreadyEnabled.selector, VAULT_ID));
        marketMakingEngine.exposed_Vault_create(params);
    }

    function test_WhenCreateIsPassedValidVaultId() external {
        Vault.CreateParams memory params = Vault.CreateParams({
            vaultId: VAULT_ID,
            depositCap: VAULT_DEPOSIT_CAP,
            withdrawalDelay: VAULT_WITHDRAW_DELAY,
            indexToken: address(zlpVault),
            collateral: collateralData
        });

        // it should create new vault
        marketMakingEngine.exposed_Vault_create(params);
    }
}
