// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";

// Open Zeppelin dependencies
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
        uint128 assetsToDeposit
    )
        external
        whenVaultDoesExist
    {
        // ensure valid vault and load vault config
        vaultId = uint128(bound(vaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
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

        assetsToDeposit = uint128(bound({ x: assetsToDeposit, min: minDeposit, max: type(uint128).max }));

        address collateral = fuzzVaultConfig.asset;

        deal(collateral, users.naruto.account, assetsToDeposit);

        UD60x18 assetsX18 = Math.convertTokenAmountToUd60x18(fuzzVaultConfig.decimals, assetsToDeposit);
        UD60x18 assetFeesX18 = assetsX18.mul(ud60x18(depositFee));
        uint256 assetsFee = Math.convertUd60x18ToTokenAmount(fuzzVaultConfig.decimals, assetFeesX18);
        uint256 assetsMinusFees = assetsToDeposit - assetsFee;

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
        uint128 vaultId,
        uint128 assetsToDeposit
    )
        external
        whenVaultDoesExist
        whenTheDepositCapIsNotReached
    {
        // ensure valid vault and load vault config
        vaultId = uint128(bound(vaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount
        address user = users.naruto.account;
        assetsToDeposit = uint128(bound(assetsToDeposit,
                                         calculateMinOfSharesToStake(vaultId),
                                         fuzzVaultConfig.depositCap));
        deal(fuzzVaultConfig.asset, user, assetsToDeposit);

        // calculate expected fees
        uint256 depositFee = vaultsConfig[fuzzVaultConfig.vaultId].depositFee;
        UD60x18 assetsX18 = Math.convertTokenAmountToUd60x18(fuzzVaultConfig.decimals, assetsToDeposit);
        UD60x18 assetFeesX18 = assetsX18.mul(ud60x18(depositFee));

        // calculate assets minus fees
        uint256 assetsFee = Math.convertUd60x18ToTokenAmount(fuzzVaultConfig.decimals, assetFeesX18);
        uint256 assetsMinusFees = assetsToDeposit - assetsFee;

        uint128 minShares = type(uint128).max;

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector, minShares, assetsMinusFees));
        marketMakingEngine.deposit(vaultId, assetsToDeposit, minShares, "", false);
    }

    function testFuzz_WhenSharesMintedAreMoreThanMinAmount(
        uint256 vaultId,
        uint256 assetsToDeposit
    )
        external
        whenVaultDoesExist
        whenTheDepositCapIsNotReached
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        assetsToDeposit = bound({
            x: assetsToDeposit,
            min: calculateMinOfSharesToStake(fuzzVaultConfig.vaultId),
            max: fuzzVaultConfig.depositCap
        });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);

        uint256 depositFee = vaultsConfig[fuzzVaultConfig.vaultId].depositFee;

        UD60x18 assetsX18 = Math.convertTokenAmountToUd60x18(fuzzVaultConfig.decimals, assetsToDeposit);
        UD60x18 assetFeesX18 = assetsX18.mul(ud60x18(depositFee));

        uint256 assetsFee = Math.convertUd60x18ToTokenAmount(fuzzVaultConfig.decimals, assetFeesX18);

        uint256 assetsMinusFees = assetsToDeposit - assetsFee;

        uint256 vaultDepositFeeRecipientAmountBeforeDeposit =
            IERC20(fuzzVaultConfig.asset).balanceOf(users.owner.account);

        marketMakingEngine.workaround_Vault_setTotalCreditDelegationWeight(fuzzVaultConfig.vaultId, 1e10);

        vm.expectEmit();
        emit VaultRouterBranch.LogDeposit(fuzzVaultConfig.vaultId, users.naruto.account, assetsMinusFees);

        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), 0, "", false);

        uint256 vaultDepositFeeRecipientAmountAfterDeposit =
            IERC20(fuzzVaultConfig.asset).balanceOf(users.owner.account);

        // it should send the fees to the vault deposit fee recipient
        assertEq(
            vaultDepositFeeRecipientAmountAfterDeposit - vaultDepositFeeRecipientAmountBeforeDeposit,
            Math.convertUd60x18ToTokenAmount(fuzzVaultConfig.decimals, assetFeesX18)
        );

        // it should mint shares to the user
        assertGt(IERC20(fuzzVaultConfig.indexToken).balanceOf(users.naruto.account), 0);
    }
}
