// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Zaros dependencies source
import { Math } from "@zaros/utils/Math.sol";
import { WithdrawalRequest } from "@zaros/market-making/leaves/WithdrawalRequest.sol";
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";

// Open Zeppelin dependencies
import { IERC20, IERC4626 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

// PRB Math
import { UD60x18, ud60x18 } from "@prb-math/ud60x18.sol";

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

        assetsToDeposit = bound({
            x: assetsToDeposit,
            min: calculateMinOfSharesToStake(fuzzVaultConfig.vaultId),
            max: fuzzVaultConfig.depositCap
        });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);
        // marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), 0);

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

        assetsToDeposit = bound({
            x: assetsToDeposit,
            min: calculateMinOfSharesToStake(fuzzVaultConfig.vaultId),
            max: fuzzVaultConfig.depositCap
        });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);
        // marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), 0);

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

        assetsToDeposit = bound({
            x: assetsToDeposit,
            min: calculateMinOfSharesToStake(fuzzVaultConfig.vaultId),
            max: fuzzVaultConfig.depositCap
        });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);
        // marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), 0);

        address indexToken = fuzzVaultConfig.indexToken;
        uint256 userBalance = IERC20(indexToken).balanceOf(users.naruto.account);
        assetsToWithdraw = bound({ x: assetsToDeposit, min: 0, max: userBalance });
        IERC20(indexToken).approve(address(marketMakingEngine), assetsToWithdraw);

        marketMakingEngine.initiateWithdrawal(fuzzVaultConfig.vaultId, uint128(assetsToWithdraw));

        skip(fuzzVaultConfig.withdrawalDelay + 1);

        uint256 assetsOut = IERC4626(indexToken).previewRedeem(userBalance);

        uint256 minAssetsOut = assetsOut + 1;

        IERC20(indexToken).approve(address(marketMakingEngine), userBalance);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, minAssetsOut, assetsOut));

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

        assetsToDeposit = bound({
            x: assetsToDeposit,
            min: calculateMinOfSharesToStake(fuzzVaultConfig.vaultId),
            max: fuzzVaultConfig.depositCap
        });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);
        // marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), 0);

        address indexToken = fuzzVaultConfig.indexToken;
        uint256 userBalanceBefore = IERC20(indexToken).balanceOf(users.naruto.account);
        assetsToWithdraw = userBalanceBefore;
        IERC20(indexToken).approve(address(marketMakingEngine), assetsToWithdraw);

        marketMakingEngine.initiateWithdrawal(fuzzVaultConfig.vaultId, uint128(assetsToWithdraw));

        // fast forward block.timestamp to after withdraw delay has passed
        skip(fuzzVaultConfig.withdrawalDelay + 1);

        UD60x18 expectedAssetsX18 =
            marketMakingEngine.getIndexTokenSwapRate(fuzzVaultConfig.vaultId, uint128(assetsToWithdraw), false);

        uint256 redeemFee = vaultsConfig[fuzzVaultConfig.vaultId].redeemFee;

        UD60x18 expectedAssetsMinusRedeemFeeX18 = expectedAssetsX18.sub(expectedAssetsX18.mul(ud60x18(redeemFee)));

        UD60x18 sharesMinusRedeemFeesX18 = marketMakingEngine.getVaultAssetSwapRate(
            fuzzVaultConfig.vaultId, expectedAssetsMinusRedeemFeeX18.intoUint256(), false
        );

        uint256 vaultRedeemFeeRecipientAmountBeforeDeposit =
            IERC20(fuzzVaultConfig.asset).balanceOf(users.owner.account);

        vm.expectEmit();
        emit VaultRouterBranch.LogRedeem(
            fuzzVaultConfig.vaultId, users.naruto.account, sharesMinusRedeemFeesX18.intoUint256()
        );
        marketMakingEngine.redeem(fuzzVaultConfig.vaultId, WITHDRAW_REQUEST_ID, 0);

        uint256 vaultRedeemFeeRecipientAmountAfterDeposit =
            IERC20(fuzzVaultConfig.asset).balanceOf(users.owner.account);

        uint256 userBalanceAfter = IERC20(indexToken).balanceOf(users.naruto.account);

        WithdrawalRequest.Data memory withdrawalRequest = marketMakingEngine.exposed_WithdrawalRequest_loadExisting(
            fuzzVaultConfig.vaultId, users.naruto.account, WITHDRAW_REQUEST_ID
        );

        assertEq(withdrawalRequest.fulfilled, true);

        // it should send the fees to the vault redeem fee recipient
        assertEq(
            vaultRedeemFeeRecipientAmountAfterDeposit - vaultRedeemFeeRecipientAmountBeforeDeposit,
            expectedAssetsX18.mul(ud60x18(redeemFee)).intoUint256()
        );

        // it should transfer assets to user
        assertEq(userBalanceBefore - userBalanceAfter, assetsToWithdraw);
        assertGt(IERC20(fuzzVaultConfig.asset).balanceOf(users.naruto.account), 0);
    }
}
