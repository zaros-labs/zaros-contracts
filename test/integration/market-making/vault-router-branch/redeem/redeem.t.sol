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

    function testFuzz_RevertWhen_RequestIsFulfilled(
        uint128 vaultId,
        uint128 assetsToDeposit,
        uint128 sharesToWithdraw
    )
        external
    {
        // ensure valid vault and load vault config
        vaultId = uint128(bound(vaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount
        address user = users.naruto.account;
        assetsToDeposit = uint128(bound(assetsToDeposit,
                                         calculateMinOfSharesToStake(vaultId),
                                         fuzzVaultConfig.depositCap));

        fundUserAndDepositInVault(user, vaultId, uint128(assetsToDeposit));

        uint128 userVaultShares = uint128(IERC20(fuzzVaultConfig.indexToken).balanceOf(user));
        sharesToWithdraw = uint128(bound(sharesToWithdraw, 1, userVaultShares));

        vm.startPrank(user);
        marketMakingEngine.initiateWithdrawal(vaultId, sharesToWithdraw);

        // fast forward block.timestamp to after withdraw delay has passed
        skip(fuzzVaultConfig.withdrawalDelay + 1);

        // redeeming once works
        marketMakingEngine.redeem(vaultId, WITHDRAW_REQUEST_ID, 0);

        // redeeming the same id twice fails
        vm.expectRevert(abi.encodeWithSelector(Errors.WithdrawalRequestAlreadyFulfilled.selector));
        marketMakingEngine.redeem(fuzzVaultConfig.vaultId, WITHDRAW_REQUEST_ID, 0);
    }

    modifier whenRequestIsNotFulfulled() {
        _;
    }

    function testFuzz_RevertWhen_DelayHasNotPassed(
        uint128 vaultId,
        uint128 assetsToDeposit,
        uint128 sharesToWithdraw
    )
        external
        whenRequestIsNotFulfulled
    {
        // ensure valid vault and load vault config
        vaultId = uint128(bound(vaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount
        address user = users.naruto.account;
        assetsToDeposit = uint128(bound(assetsToDeposit,
                                         calculateMinOfSharesToStake(vaultId),
                                         fuzzVaultConfig.depositCap));

        fundUserAndDepositInVault(user, vaultId, uint128(assetsToDeposit));

        uint128 userVaultShares = uint128(IERC20(fuzzVaultConfig.indexToken).balanceOf(user));
        sharesToWithdraw = uint128(bound(sharesToWithdraw, 1, userVaultShares));

        vm.startPrank(user);
        marketMakingEngine.initiateWithdrawal(vaultId, sharesToWithdraw);

        // immediate redemption should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.WithdrawDelayNotPassed.selector));
        marketMakingEngine.redeem(fuzzVaultConfig.vaultId, WITHDRAW_REQUEST_ID, 0);
    }

    modifier whenDelayHasPassed() {
        _;
    }

    function testFuzz_RevertWhen_AssetsAreLessThanMinAmount(
        uint128 vaultId,
        uint128 assetsToDeposit,
        uint128 sharesToWithdraw
    )
        external
        whenRequestIsNotFulfulled
        whenDelayHasPassed
    {
        // ensure valid vault and load vault config
        vaultId = uint128(bound(vaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount
        address user = users.naruto.account;
        assetsToDeposit = uint128(bound(assetsToDeposit,
                                         calculateMinOfSharesToStake(vaultId),
                                         fuzzVaultConfig.depositCap));

        fundUserAndDepositInVault(user, vaultId, uint128(assetsToDeposit));

        uint128 userVaultShares = uint128(IERC20(fuzzVaultConfig.indexToken).balanceOf(user));
        sharesToWithdraw = uint128(bound(sharesToWithdraw, 1, userVaultShares));

        vm.startPrank(user);
        marketMakingEngine.initiateWithdrawal(vaultId, sharesToWithdraw);

        // fast forward block.timestamp to after withdraw delay has passed
        skip(fuzzVaultConfig.withdrawalDelay + 1);

        UD60x18 expectedAssetsX18 =
            marketMakingEngine.getIndexTokenSwapRate(vaultId, sharesToWithdraw, false);

        uint256 redeemFee = vaultsConfig[fuzzVaultConfig.vaultId].redeemFee;

        UD60x18 expectedAssetsMinusRedeemFeeX18 = expectedAssetsX18.sub(expectedAssetsX18.mul(ud60x18(redeemFee)));

        UD60x18 sharesMinusRedeemFeesX18 = marketMakingEngine.getVaultAssetSwapRate(
            vaultId, expectedAssetsMinusRedeemFeeX18.intoUint256(), false
        );

        uint256 assetsOut = IERC4626(fuzzVaultConfig.indexToken).previewRedeem(sharesMinusRedeemFeesX18.intoUint256());
        uint256 minAssetsOut = assetsOut + 1;

        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, minAssetsOut, assetsOut));
        marketMakingEngine.redeem(vaultId, WITHDRAW_REQUEST_ID, minAssetsOut);
    }

    struct RedeemState {
        // asset balances
        uint256 redeemerAssetBal;
        uint256 feeReceiverAssetBal;
        uint256 vaultAssetBal;

        // vault balances
        uint256 redeemerVaultBal;
        uint256 marketEngineVaultBal;
    }

    function _getRedeemState(
        address redeemer, address feeReceiver, IERC20 assetToken, IERC20 vault
    ) internal view returns (RedeemState memory state) {
        state.redeemerAssetBal     = assetToken.balanceOf(redeemer);
        state.feeReceiverAssetBal  = assetToken.balanceOf(feeReceiver);
        state.vaultAssetBal        = assetToken.balanceOf(address(vault));
        state.redeemerVaultBal     = vault.balanceOf(redeemer);
        state.marketEngineVaultBal = vault.balanceOf(address(marketMakingEngine));
    }

    function testFuzz_WhenAssetsAreMoreThanMinAmount(
        uint128 vaultId,
        uint128 assetsToDeposit,
        uint128 sharesToWithdraw
    )
        external
        whenRequestIsNotFulfulled
        whenDelayHasPassed
    {
        // ensure valid vault and load vault config
        vaultId = uint128(bound(vaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount
        address user = users.naruto.account;
        assetsToDeposit = uint128(bound(assetsToDeposit,
                                         calculateMinOfSharesToStake(vaultId),
                                         fuzzVaultConfig.depositCap));

        // peform the deposit
        fundUserAndDepositInVault(user, vaultId, uint128(assetsToDeposit));

        uint128 userVaultShares = uint128(IERC20(fuzzVaultConfig.indexToken).balanceOf(user));
        sharesToWithdraw = uint128(bound(sharesToWithdraw, 1, userVaultShares));

        // intiate the withdrawal
        vm.startPrank(user);
        marketMakingEngine.initiateWithdrawal(vaultId, sharesToWithdraw);

        // fast forward block.timestamp to after withdraw delay has passed
        skip(fuzzVaultConfig.withdrawalDelay + 1);

        UD60x18 expectedAssetsX18 =
            marketMakingEngine.getIndexTokenSwapRate(vaultId, sharesToWithdraw, false);

        uint256 redeemFee = vaultsConfig[vaultId].redeemFee;

        UD60x18 expectedAssetsMinusRedeemFeeX18 = expectedAssetsX18.sub(expectedAssetsX18.mul(ud60x18(redeemFee)));

        UD60x18 sharesMinusRedeemFeesX18 = marketMakingEngine.getVaultAssetSwapRate(
            vaultId, expectedAssetsMinusRedeemFeeX18.intoUint256(), false
        );

        // save and verify pre state
        RedeemState memory pre = _getRedeemState(user,
                                                 users.vaultFeeRecipient.account,
                                                 IERC20(fuzzVaultConfig.asset),
                                                 IERC20(fuzzVaultConfig.indexToken));

        assertEq(pre.marketEngineVaultBal, sharesToWithdraw, "MarketEngine received shares from initiated withdraw");
        assertEq(pre.redeemerVaultBal, userVaultShares - sharesToWithdraw, "Shares deducted from Redeemer");
        assertEq(pre.feeReceiverAssetBal + pre.vaultAssetBal, assetsToDeposit, "All deposited assets accounted");

        // perform the redemption
        vm.expectEmit();
        emit VaultRouterBranch.LogRedeem(
            vaultId, user, sharesMinusRedeemFeesX18.intoUint256()
        );
        marketMakingEngine.redeem(vaultId, WITHDRAW_REQUEST_ID, 0);

        // save and verify post state
        RedeemState memory post = _getRedeemState(user,
                                                  users.vaultFeeRecipient.account,
                                                  IERC20(fuzzVaultConfig.asset),
                                                  IERC20(fuzzVaultConfig.indexToken));
        
        // verify withdrawal request marked as fulfilled
        WithdrawalRequest.Data memory withdrawalRequest = marketMakingEngine.exposed_WithdrawalRequest_loadExisting(
            vaultId, user, WITHDRAW_REQUEST_ID
        );
        assertTrue(withdrawalRequest.fulfilled);

        // verify redeem fees paid to the vault redeem fee recipient
        assertEq(
            post.feeReceiverAssetBal - pre.feeReceiverAssetBal,
            expectedAssetsX18.mul(ud60x18(redeemFee)).intoUint256(),
            "Redeem fees paid to FeeReceiver"
        );

        assertEq(post.redeemerVaultBal, userVaultShares - sharesToWithdraw, "Shares deducted from Redeemer");
        assertEq(post.marketEngineVaultBal, 0, "No shares stuck in market engine");

        assertEq(post.redeemerAssetBal,
                 expectedAssetsMinusRedeemFeeX18.intoUint256(),
                 "Redeemer received correct asset tokens");
        assertEq(post.redeemerAssetBal + post.feeReceiverAssetBal + post.vaultAssetBal,
                 assetsToDeposit,
                 "All deposited assets accounted");
    }
}
