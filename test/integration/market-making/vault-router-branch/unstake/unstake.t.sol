// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract MarketMaking_unstake_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        createVault();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_UserDoesNotHaveEnoguhtStakedShares() external {
        uint256 sharesToStake = 1e18;
        address indexToken = marketMakingEngine.workaround_Vault_getIndexToken(VAULT_ID);
        deal(address(indexToken), users.naruto.account, sharesToStake);

        IERC20(indexToken).approve(address(marketMakingEngine), sharesToStake);
        marketMakingEngine.stake(VAULT_ID, sharesToStake, "", false);

        uint256 sharesToUnstake = sharesToStake + 1;

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.NotEnoughShares.selector));
        marketMakingEngine.unstake(VAULT_ID, sharesToUnstake);
    }

    function test_WhenUserHasStakedShares() external {
        uint256 sharesToStake = 1e18;
        address indexToken = marketMakingEngine.workaround_Vault_getIndexToken(VAULT_ID);
        deal(address(indexToken), users.naruto.account, sharesToStake);

        IERC20(indexToken).approve(address(marketMakingEngine), sharesToStake);
        marketMakingEngine.stake(VAULT_ID, sharesToStake, "", false);

        uint256 sharesToUnstake = sharesToStake;

        // it should log unstake event
        vm.expectEmit();
        emit VaultRouterBranch.LogUnstake(VAULT_ID, users.naruto.account, sharesToUnstake);
        marketMakingEngine.unstake(VAULT_ID, sharesToUnstake);

        uint256 userBalanceAfter = IERC20(indexToken).balanceOf(users.naruto.account);
        assertEq(userBalanceAfter, sharesToUnstake);
    }
}
