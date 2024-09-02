// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { Errors } from "@zaros/utils/Errors.sol";
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract MarketMaking_initiateWithdraw_Test is Base_Test {

    function setUp() public virtual override {
        Base_Test.setUp();
        createVault();
        changePrank({ msgSender: users.naruto.account });
        depositInVault(1e18);
    }

    modifier whenInitiateWithdrawIsCalled() {
        _;
    }

    function test_RevertWhen_AmountIsZero() external whenInitiateWithdrawIsCalled {
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "sharesAmount"));
        marketMakingEngine.initiateWithdrawal(VAULT_ID, 0);
    }

    function test_RevertWhen_VaultIdIsInvalid() external whenInitiateWithdrawIsCalled {
        uint256 invalidVaultId = 0;
        uint256 sharesToWithdraw = 1e18;
        vm.expectRevert();
        marketMakingEngine.initiateWithdrawal(invalidVaultId, sharesToWithdraw);
    }

    function test_RevertWhen_SharesAmountIsGtUserBalance() external whenInitiateWithdrawIsCalled {
        address indexToken = marketMakingEngine.workaround_Vault_getIndexToken(VAULT_ID);
        uint256 sharesToWithdraw = IERC20(indexToken).balanceOf(users.naruto.account) + 1;

        vm.expectRevert(Errors.NotEnoughShares.selector);
        marketMakingEngine.initiateWithdrawal(VAULT_ID, sharesToWithdraw);
    }

    function test_WhenUserHasSharesBalance() external whenInitiateWithdrawIsCalled {
        address indexToken = marketMakingEngine.workaround_Vault_getIndexToken(VAULT_ID);
        uint256 sharesToWithdraw = IERC20(indexToken).balanceOf(users.naruto.account);

        vm.expectEmit();
        emit VaultRouterBranch.LogInitiateWithdraw(VAULT_ID, users.naruto.account, sharesToWithdraw);
        marketMakingEngine.initiateWithdrawal(VAULT_ID, sharesToWithdraw);
    }
}
