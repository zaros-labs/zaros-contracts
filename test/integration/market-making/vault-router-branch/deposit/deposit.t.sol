// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract Deposit_Integration_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertWhen_VaultDoesNotExist(uint128 amountToDeposit) external {
        uint128 minSharesOut = 0;

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.VaultDoesNotExist.selector));
        marketMakingEngine.deposit(INVALID_VAULT_ID, amountToDeposit, minSharesOut);
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

        assetsToDeposit = bound({ x: assetsToDeposit, min: fuzzVaultConfig.depositCap + 1, max: type(uint128).max });

        address collateral = fuzzVaultConfig.asset;

        deal(collateral, users.naruto.account, assetsToDeposit);

        // it should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.DepositCap.selector,
                collateral,
                convertTokenAmountToUd60x18(collateral, assetsToDeposit),
                convertTokenAmountToUd60x18(collateral, fuzzVaultConfig.depositCap)
            )
        );
        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), 0);
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

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.SlippageCheckFailed.selector));
        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), type(uint128).max);
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

        assetsToDeposit = bound({ x: assetsToDeposit, min: 1, max: fuzzVaultConfig.depositCap });
        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);

        vm.expectEmit();
        emit VaultRouterBranch.LogDeposit(fuzzVaultConfig.vaultId, users.naruto.account, assetsToDeposit);
        marketMakingEngine.deposit(fuzzVaultConfig.vaultId, uint128(assetsToDeposit), 0);

        // it should mint shares to the user
        assertGt(IERC20(fuzzVaultConfig.indexToken).balanceOf(users.naruto.account), 0);
    }
}
