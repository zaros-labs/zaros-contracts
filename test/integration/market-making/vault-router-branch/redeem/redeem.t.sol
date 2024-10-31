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

contract Redeem_Integration_Test is Base_Test {
    uint128 constant WITHDRAW_REQUEST_ID = 1;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertWhen_RequestIsFulfulled(
        uint256 vaultId,
        uint256 assetsToDeposit,
        uint256 assetsToWithdraw
    )
        external
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDeposit = bound({ x: assetsToDeposit, min: 1, max: fuzzVaultConfig.depositCap });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);
        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), 0);

        address indexToken = fuzzVaultConfig.indexToken;
        uint256 userBalance = IERC20(indexToken).balanceOf(users.naruto.account);
        assetsToWithdraw = bound({ x: assetsToDeposit, min: 0, max: userBalance });
        IERC20(indexToken).approve(address(marketMakingEngine), assetsToWithdraw);

        marketMakingEngine.initiateWithdrawal(fuzzVaultConfig.vaultId, uint128(assetsToWithdraw));

        // fast forward block.timestamp to after withdraw delay has passed
        skip(fuzzVaultConfig.withdrawalDelay + 1);

        marketMakingEngine.redeem(fuzzVaultConfig.vaultId, WITHDRAW_REQUEST_ID, 0);
        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.WithdrawalRequestAlreadyFullfilled.selector));
        marketMakingEngine.redeem(fuzzVaultConfig.vaultId, WITHDRAW_REQUEST_ID, 0);
    }

    modifier whenRequestIsNotFulfulled() {
        _;
    }

    function testFuzz_RevertWhen_DelayHasNotPassed(
        uint256 vaultId,
        uint256 assetsToDeposit,
        uint256 assetsToWithdraw
    )
        external
        whenRequestIsNotFulfulled
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDeposit = bound({ x: assetsToDeposit, min: 1, max: fuzzVaultConfig.depositCap });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);
        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), 0);

        address indexToken = fuzzVaultConfig.indexToken;
        uint256 userBalance = IERC20(indexToken).balanceOf(users.naruto.account);
        assetsToWithdraw = bound({ x: assetsToDeposit, min: 0, max: userBalance });
        IERC20(indexToken).approve(address(marketMakingEngine), assetsToWithdraw);

        marketMakingEngine.initiateWithdrawal(fuzzVaultConfig.vaultId, uint128(assetsToWithdraw));

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.WithdrawDelayNotPassed.selector));
        marketMakingEngine.redeem(fuzzVaultConfig.vaultId, WITHDRAW_REQUEST_ID, 0);
    }

    modifier whenDelayHasPassed() {
        _;
    }

    function testFuzz_RevertWhen_AssetsAreLessThenMinAmount(
        uint256 vaultId,
        uint256 assetsToDeposit,
        uint256 assetsToWithdraw
    )
        external
        whenRequestIsNotFulfulled
        whenDelayHasPassed
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDeposit = bound({ x: assetsToDeposit, min: 1, max: fuzzVaultConfig.depositCap });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);
        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), 0);

        address indexToken = fuzzVaultConfig.indexToken;
        uint256 userBalance = IERC20(indexToken).balanceOf(users.naruto.account);
        assetsToWithdraw = bound({ x: assetsToDeposit, min: 0, max: userBalance });
        IERC20(indexToken).approve(address(marketMakingEngine), assetsToWithdraw);

        marketMakingEngine.initiateWithdrawal(fuzzVaultConfig.vaultId, uint128(assetsToWithdraw));

        skip(fuzzVaultConfig.withdrawalDelay + 1);
        uint256 minAssetsOut = IERC4626(indexToken).previewRedeem(userBalance) + 1;

        IERC20(indexToken).approve(address(marketMakingEngine), userBalance);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector));

        marketMakingEngine.redeem(fuzzVaultConfig.vaultId, WITHDRAW_REQUEST_ID, minAssetsOut);
    }

    function testFuzz_WhenAssetsAreMoreThanMinAmount(
        uint256 vaultId,
        uint256 assetsToDeposit,
        uint256 assetsToWithdraw
    )
        external
        whenRequestIsNotFulfulled
        whenDelayHasPassed
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        uint256 minAssetsToDeposit = 10 ** (18 - fuzzVaultConfig.decimals);
        assetsToDeposit = bound({ x: assetsToDeposit, min: minAssetsToDeposit, max: fuzzVaultConfig.depositCap });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);
        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), 0);

        address indexToken = fuzzVaultConfig.indexToken;
        uint256 userBalanceBefore = IERC20(indexToken).balanceOf(users.naruto.account);
        assetsToWithdraw = bound({ x: assetsToDeposit, min: minAssetsToDeposit, max: userBalanceBefore });
        IERC20(indexToken).approve(address(marketMakingEngine), assetsToWithdraw);

        marketMakingEngine.initiateWithdrawal(fuzzVaultConfig.vaultId, uint128(assetsToWithdraw));

        // fast forward block.timestamp to after withdraw delay has passed
        skip(fuzzVaultConfig.withdrawalDelay + 1);

        vm.expectEmit();
        emit VaultRouterBranch.LogRedeem(
            fuzzVaultConfig.vaultId, users.naruto.account, IERC4626(indexToken).previewRedeem(assetsToWithdraw)
        );
        marketMakingEngine.redeem(fuzzVaultConfig.vaultId, WITHDRAW_REQUEST_ID, 0);

        uint256 userBalanceAfter = IERC20(indexToken).balanceOf(users.naruto.account);

        WithdrawalRequest.Data memory withdrawalRequest = marketMakingEngine.exposed_WithdrawalRequest_loadExisting(
            fuzzVaultConfig.vaultId, users.naruto.account, WITHDRAW_REQUEST_ID
        );

        assertEq(withdrawalRequest.fulfilled, true);

        // it should transfer assets to user
        assertEq(userBalanceBefore - userBalanceAfter, assetsToWithdraw);
        assertGt(IERC20(fuzzVaultConfig.asset).balanceOf(users.naruto.account), 0);
    }
}
