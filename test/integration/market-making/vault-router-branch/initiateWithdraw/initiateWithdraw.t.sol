// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies test
import { Base_Test } from "test/Base.t.sol";

// Zaros dependencies source
import { Errors } from "@zaros/utils/Errors.sol";
import { VaultRouterBranch } from "@zaros/market-making/branches/VaultRouterBranch.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

contract InitiateWithdraw_Integration_Test is Base_Test {
    using SafeCast for uint256;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertWhen_AmountIsZero(uint256 vaultId, uint256 assetsToDeposit) external {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        assetsToDeposit = bound({ x: assetsToDeposit, min: 1, max: fuzzVaultConfig.depositCap });

        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);
        depositInVault(fuzzVaultConfig.vaultId, uint128(assetsToDeposit));

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "sharesAmount"));
        marketMakingEngine.initiateWithdrawal(fuzzVaultConfig.vaultId, 0);
    }

    modifier whenAmountIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_VaultIdIsInvalid(uint256 sharesToWithdraw) external whenAmountIsNotZero {
        sharesToWithdraw = bound({ x: sharesToWithdraw, min: 1, max: type(uint128).max });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.VaultDoesNotExist.selector));
        marketMakingEngine.initiateWithdrawal(INVALID_VAULT_ID, uint128(sharesToWithdraw));
    }

    modifier whenVaultIdIsValid() {
        _;
    }

    function testFuzz_RevertWhen_SharesAmountIsGtUserBalance(
        uint256 vaultId,
        uint256 assetsToDeposit
    )
        external
        whenAmountIsNotZero
        whenVaultIdIsValid
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        assetsToDeposit = bound({ x: assetsToDeposit, min: 1, max: fuzzVaultConfig.depositCap });

        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);
        depositInVault(fuzzVaultConfig.vaultId, uint128(assetsToDeposit));

        uint128 sharesToWithdraw = IERC20(fuzzVaultConfig.indexToken).balanceOf(users.naruto.account).toUint128() + 1;

        // it should revert
        vm.expectRevert(Errors.NotEnoughShares.selector);
        marketMakingEngine.initiateWithdrawal(fuzzVaultConfig.vaultId, sharesToWithdraw);
    }

    modifier whenSharesAmountIsNotGtUserBalance() {
        _;
    }

    function testFuzz_GivenUserHasSharesBalance(
        uint256 vaultId,
        uint256 assetsToDeposit
    )
        external
        whenAmountIsNotZero
        whenVaultIdIsValid
        whenSharesAmountIsNotGtUserBalance
    {
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);
        assetsToDeposit = bound({ x: assetsToDeposit, min: 1, max: fuzzVaultConfig.depositCap });

        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);
        depositInVault(fuzzVaultConfig.vaultId, uint128(assetsToDeposit));

        uint128 sharesToWithdraw = IERC20(fuzzVaultConfig.indexToken).balanceOf(users.naruto.account).toUint128();

        // it should create withdraw request
        vm.expectEmit();
        emit VaultRouterBranch.LogInitiateWithdrawal(fuzzVaultConfig.vaultId, users.naruto.account, sharesToWithdraw);
        marketMakingEngine.initiateWithdrawal(fuzzVaultConfig.vaultId, sharesToWithdraw);
    }
}
