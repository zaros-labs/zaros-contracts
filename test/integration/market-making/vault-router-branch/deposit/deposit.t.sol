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
        uint256 assetsToDeposit = VAULT_DEPOSIT_CAP + 1;
        deal(address(wEth), users.naruto.account, assetsToDeposit);

        vm.expectRevert(abi.encodeWithSelector(Errors.DepositCapReached.selector, VAULT_ID, assetsToDeposit, VAULT_DEPOSIT_CAP));
        marketMakingEngine.deposit(VAULT_ID, assetsToDeposit, 0);
    }

    function test_WhenUserHasEnoughAssets() external givenAUserDeposits {
        uint256 assetsToDeposit = 1e18;
        deal(address(wEth), users.naruto.account, assetsToDeposit);

        vm.expectEmit();
        emit VaultRouterBranch.LogDeposit(VAULT_ID, users.naruto.account, assetsToDeposit);
        marketMakingEngine.deposit(VAULT_ID, assetsToDeposit, 0);
    }

    function test_RevertWhen_SharesMintedAreLessThanMinAmount() external givenAUserDeposits {
        // it should revert
    }

    function test_RevertWhen_VaultDoesNotExist() external givenAUserDeposits {
        uint256 invalidVaultId = 0;
        uint256 amount = 1e18;
        uint256 minSharesOut = 0;

        vm.expectRevert();
        marketMakingEngine.deposit(invalidVaultId, amount, minSharesOut);
    }
}
