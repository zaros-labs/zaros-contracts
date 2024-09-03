// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Zaros dependencies source
import { WithdrawalRequest } from "@zaros/market-making/leaves/WithdrawalRequest.sol";
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";

// Open Zeppelin dependencies
import { IERC20, IERC4626 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

contract MarketMaking_redeem_Test is Base_Test {
    uint256 constant WITHDRAW_REQUEST_ID = 0;

    function setUp() public virtual override {
        Base_Test.setUp();
        createVault();
        changePrank({ msgSender: users.naruto.account });
        depositInVault(1e18);
        marketMakingEngine.initiateWithdrawal(VAULT_ID, 1e18);
    }

    modifier whenRedeemIsCalled() {
        _;
    }

    function test_WhenDelayHasPassed() external whenRedeemIsCalled {
        // fast forward block.timestamp to after withdraw delay has passed
        skip(VAULT_WITHDRAW_DELAY + 1);

        uint256 minAssetsOut = 0;

        address indexToken = marketMakingEngine.workaround_Vault_getIndexToken(VAULT_ID);
        uint256 userBalance = IERC20(indexToken).balanceOf(users.naruto.account);

        IERC20(indexToken).approve(address(marketMakingEngine), userBalance);

        vm.expectEmit();
        emit VaultRouterBranch.LogRedeem(VAULT_ID, users.naruto.account, userBalance);
        marketMakingEngine.redeem(VAULT_ID, WITHDRAW_REQUEST_ID, minAssetsOut);

        WithdrawalRequest.Data memory withdrawalRequest =
            marketMakingEngine.exposed_WithdrawalRequest_load(VAULT_ID, users.naruto.account, 0);

        assertEq(withdrawalRequest.fulfilled, true);

        // it should transfer assets to user
        assertEq(IERC20(indexToken).balanceOf(users.naruto.account), 0);
    }

    function test_RevertWhen_DelayHasNotPassed() external whenRedeemIsCalled {
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.WithdrawDelayNotPassed.selector));
        marketMakingEngine.redeem(VAULT_ID, WITHDRAW_REQUEST_ID, 0);
    }

    function test_RevertWhen_AssetsAreLessThenMinAmount() external whenRedeemIsCalled {
        skip(VAULT_WITHDRAW_DELAY + 1);
        address indexToken = marketMakingEngine.workaround_Vault_getIndexToken(VAULT_ID);
        uint256 userBalance = IERC20(indexToken).balanceOf(users.naruto.account);

        uint256 minAssetsOut = IERC4626(indexToken).previewRedeem(userBalance) + 1;

        IERC20(indexToken).approve(address(marketMakingEngine), userBalance);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector));
        marketMakingEngine.redeem(VAULT_ID, WITHDRAW_REQUEST_ID, minAssetsOut);
    }

    function test_RevertWhen_RequiestIsFulfulled() external whenRedeemIsCalled {
        skip(VAULT_WITHDRAW_DELAY + 1);

        uint256 minAssetsOut = 0;

        address indexToken = marketMakingEngine.workaround_Vault_getIndexToken(VAULT_ID);
        uint256 userBalance = IERC20(indexToken).balanceOf(users.naruto.account);

        IERC20(indexToken).approve(address(marketMakingEngine), userBalance);

        marketMakingEngine.redeem(VAULT_ID, WITHDRAW_REQUEST_ID, minAssetsOut);
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.WithdrawalRequestAlreadyFullfilled.selector));
        marketMakingEngine.redeem(VAULT_ID, WITHDRAW_REQUEST_ID, minAssetsOut);
    }
}
