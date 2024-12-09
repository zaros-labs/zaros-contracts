// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";
import { Market } from "@zaros/market-making/leaves/Market.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";

// Open Zeppelin dependencies
import { IERC4626 } from "@openzeppelin/interfaces/IERC4626.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { ERC4626Upgradeable } from "@openzeppelin-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

// PRB Math
import { UD60x18, ud60x18 } from "@prb-math/ud60x18.sol";

contract Deposit_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_VaultDoesNotExist(uint128 assetsToDeposit) external {
        assetsToDeposit = uint128(bound(assetsToDeposit, 1, type(uint128).max));

        uint128 minSharesOut = 0;

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.VaultDoesNotExist.selector, INVALID_VAULT_ID));
        marketMakingEngine.deposit(INVALID_VAULT_ID, assetsToDeposit, minSharesOut, "", false);
    }

    modifier whenVaultDoesExist() {
        _;
    }

    function testFuzz_RevertWhen_TheDepositCapIsReached(
        uint128 vaultId,
        uint256 assetsToDeposit
    )
        external
        whenVaultDoesExist
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        marketMakingEngine.workaround_Collateral_setParams(
            fuzzVaultConfig.asset,
            fuzzVaultConfig.creditRatio,
            fuzzVaultConfig.isEnabled,
            fuzzVaultConfig.decimals,
            fuzzVaultConfig.priceAdapter
        );

        uint256 depositFee = vaultsConfig[fuzzVaultConfig.vaultId].depositFee;

        uint256 minDeposit = ud60x18(fuzzVaultConfig.depositCap).add(
            ud60x18(fuzzVaultConfig.depositCap).mul(ud60x18(depositFee))
        ).add(ud60x18(fuzzVaultConfig.depositCap)).intoUint256();

        assetsToDeposit = bound({ x: assetsToDeposit, min: minDeposit, max: type(uint128).max });

        address collateral = fuzzVaultConfig.asset;

        deal(collateral, users.naruto.account, assetsToDeposit);

        // calculate expected fees
        UD60x18 assetsX18 = Math.convertTokenAmountToUd60x18(fuzzVaultConfig.decimals, assetsToDeposit);
        UD60x18 assetFeesX18 = assetsX18.mul(ud60x18(depositFee));
        uint256 expectedAssetFees = Math.convertUd60x18ToTokenAmount(fuzzVaultConfig.decimals, assetFeesX18);
        uint256 assetsMinusFees = assetsToDeposit - expectedAssetFees;

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC4626Upgradeable.ERC4626ExceededMaxDeposit.selector,
                address(users.naruto.account),
                assetsMinusFees,
                fuzzVaultConfig.depositCap
            )
        );
        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), 0, "", false);
    }

    modifier whenTheDepositCapIsNotReached() {
        _;
    }

    function testFuzz_RevertWhen_SharesMintedAreLessThanMinAmount(
        uint256 vaultId,
        uint256 assetsToDeposit
    )
        external
        whenVaultDoesExist
        whenTheDepositCapIsNotReached
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDeposit = bound({ x: assetsToDeposit, min: 1, max: fuzzVaultConfig.depositCap });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);

        uint256 minShares = type(uint128).max;

        // it should revert - need to correctly calculate expected received shares
        // in order to perfectly match error. Other option is to use `vm.expectPartialRevert`
        // but this is not supported by prb-test
        //uint256 receivedShares = IERC4626(fuzzVaultConfig.indexToken).previewDeposit(assetsToDeposit);
        //vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, minShares, expectedShares));
        vm.expectRevert();
        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), uint128(minShares), "", false);
    }


    struct DepositState {
        // asset balances
        uint256 depositorAssetBal;
        uint256 feeReceiverAssetBal;
        uint256 vaultAssetBal;
        uint256 marketEngineAssetBal;

        // vault balances
        uint256 depositorVaultBal;
        uint256 marketEngineVaultBal;
    }

    function _getDepositState(
        address depositor, address feeReceiver,
        IERC20 assetToken, IERC20 vault
    ) internal view returns (DepositState memory state) {
        state.depositorAssetBal    = assetToken.balanceOf(depositor);
        state.feeReceiverAssetBal  = assetToken.balanceOf(feeReceiver);
        state.vaultAssetBal        = assetToken.balanceOf(address(vault));
        state.marketEngineAssetBal = assetToken.balanceOf(address(marketMakingEngine));
        state.depositorVaultBal    = vault.balanceOf(depositor);
        state.marketEngineVaultBal = vault.balanceOf(address(marketMakingEngine));
    }

    function testFuzz_InitialState_WhenSharesMintedAreMoreThanMinAmount(
        uint128 vaultId,
        uint128 assetsToDeposit
    ) external {
        // ensure valid vault
        vaultId = uint128(bound(vaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));

        // load vault config
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount
        address user = users.naruto.account;
        assetsToDeposit = uint128(bound(assetsToDeposit,
                                         calculateMinOfSharesToStake(vaultId),
                                         fuzzVaultConfig.depositCap));
        deal(fuzzVaultConfig.asset, user, assetsToDeposit);

        // verify initial state of vault's connected markets
        uint128[] memory connectedMarkets = marketMakingEngine.workaround_Vault_getConnectedMarkets(vaultId);
        assertEq(connectedMarkets.length, 2);

        for(uint128 i; i<2; i++) {
            Market.Data storage market = Market.load(connectedMarkets[i]);
            assertEq(market.totalDelegatedCreditUsd, 0);
        }        

        // calculate expected fees
        UD60x18 assetsX18 = Math.convertTokenAmountToUd60x18(fuzzVaultConfig.decimals, assetsToDeposit);
        UD60x18 assetFeesX18 = assetsX18.mul(ud60x18(vaultsConfig[vaultId].depositFee));
        uint256 expectedAssetFees = Math.convertUd60x18ToTokenAmount(fuzzVaultConfig.decimals, assetFeesX18);
        uint256 assetsMinusFees = assetsToDeposit - expectedAssetFees;

        // save and verify pre state
        DepositState memory pre = _getDepositState(user,
                                                   users.vaultFeeRecipient.account,
                                                   IERC20(fuzzVaultConfig.asset),
                                                   IERC20(fuzzVaultConfig.indexToken));

        assertEq(pre.depositorAssetBal, assetsToDeposit, "Depositor has assets to deposit");
        assertEq(pre.feeReceiverAssetBal, 0 , "FeeReceiver has no assets");
        assertEq(pre.vaultAssetBal, 0, "Vault has no assets");
        assertEq(pre.marketEngineAssetBal, 0, "MarketEngine has no assets");
        assertEq(pre.depositorVaultBal, 0, "Depositor has no vault shares");
        assertEq(pre.marketEngineVaultBal, 0, "MarketEngine has no vault shares");

        // perform the deposit
        vm.startPrank(user);
        vm.expectEmit();
        emit VaultRouterBranch.LogDeposit(vaultId, user, assetsMinusFees);
        marketMakingEngine.deposit(vaultId, assetsToDeposit, 0, "", false);

        // save and verify post state
        DepositState memory post = _getDepositState(user,
                                                    users.vaultFeeRecipient.account,
                                                    IERC20(fuzzVaultConfig.asset),
                                                    IERC20(fuzzVaultConfig.indexToken));

        assertEq(post.depositorAssetBal, 0, "Depositor lost assets after deposit");
        assertEq(post.feeReceiverAssetBal, expectedAssetFees, "FeeReceiver got asset fees");
        assertEq(post.vaultAssetBal, assetsMinusFees, "Vault got assets minus fees");
        assertEq(post.marketEngineAssetBal, 0, "No assets stuck in MarketEngine");

        assertGt(post.depositorVaultBal, 0, "Depositor got vault shares");
        assertEq(post.marketEngineVaultBal, 0, "MarketEngine got no vault shares");
    }
}
