// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract MarketMaking_deposit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        createVault();
        changePrank({ msgSender: users.naruto.account });
    }

    modifier givenAUserDeposits() {
        _;
    }

    function test_RevertWhen_TheDepositCapIsReached() external givenAUserDeposits {
        uint128 assetsToDeposit = VAULT_DEPOSIT_CAP + 1;

        address collateral = marketMakingEngine.workaround_Vault_getVaultAsset(VAULT_ID);

        deal(address(collateral), users.naruto.account, assetsToDeposit);

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.DepositCap.selector,
                address(collateral),
                convertTokenAmountToUd60x18(address(collateral), assetsToDeposit),
                VAULT_DEPOSIT_CAP
            )
        );
        marketMakingEngine.deposit(VAULT_ID, assetsToDeposit, 0);
    }

    function test_WhenUserHasEnoughAssets() external givenAUserDeposits {
        uint128 assetsToDeposit = 1e18;
        deal(address(wEth), users.naruto.account, assetsToDeposit);

        vm.expectEmit();
        emit VaultRouterBranch.LogDeposit(VAULT_ID, users.naruto.account, assetsToDeposit);
        marketMakingEngine.deposit(VAULT_ID, assetsToDeposit, 0);

        // it should mint shares to the user
        assertGt(zlpVault.balanceOf(users.naruto.account), 0);
    }

    function test_RevertWhen_SharesMintedAreLessThanMinAmount() external givenAUserDeposits {
        uint128 assetsToDeposit = 1e18;
        deal(address(wEth), users.naruto.account, assetsToDeposit);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector));
        marketMakingEngine.deposit(VAULT_ID, assetsToDeposit, type(uint128).max);
    }

    function test_RevertWhen_VaultDoesNotExist() external givenAUserDeposits {
        uint128 invalidVaultId = 0;
        uint128 amount = 1e18;
        uint128 minSharesOut = 0;

        // it should revert
        vm.expectRevert();
        marketMakingEngine.deposit(invalidVaultId, amount, minSharesOut);
    }
}
