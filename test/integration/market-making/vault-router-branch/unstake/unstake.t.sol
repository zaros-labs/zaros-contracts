// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

contract Unstake_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertWhen_UserDoesNotHaveEnoguhtStakedShares(
        uint256 vaultId,
        uint256 depositAmount
    )
        external
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        depositAmount = bound({ x: depositAmount, min: 1, max: fuzzVaultConfig.depositCap });

        depositAndStakeInVault(fuzzVaultConfig.vaultId, uint128(depositAmount));

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.NotEnoughShares.selector));
        marketMakingEngine.unstake(fuzzVaultConfig.vaultId, type(uint128).max);
    }

    function testFuzz_WhenUserHasEnoughStakedShares(uint256 vaultId, uint256 depositAmount) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        depositAmount = bound({ x: depositAmount, min: 1, max: fuzzVaultConfig.depositCap });

        depositAndStakeInVault(fuzzVaultConfig.vaultId, uint128(depositAmount));

        // it should log unstake event
        vm.expectEmit();
        emit VaultRouterBranch.LogUnstake(fuzzVaultConfig.vaultId, users.naruto.account, depositAmount);
        marketMakingEngine.unstake(fuzzVaultConfig.vaultId, depositAmount);

        uint256 userBalanceAfter = IERC20(fuzzVaultConfig.indexToken).balanceOf(users.naruto.account);
        assertEq(userBalanceAfter, depositAmount);
    }
}
