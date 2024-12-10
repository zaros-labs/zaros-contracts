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
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract InitiateWithdraw_Integration_Test is Base_Test {
    using SafeCast for uint256;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVaults(marketMakingEngine, INITIAL_VAULT_ID, FINAL_VAULT_ID);
        configureMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertWhen_AmountIsZero(uint128 vaultId, uint128 assetsToDeposit) external {
        // ensure valid vault and load vault config
        vaultId = uint128(bound(vaultId, INITIAL_VAULT_ID, FINAL_VAULT_ID));
        VaultConfig memory fuzzVaultConfig = getFuzzVaultConfig(vaultId);

        // ensure valid deposit amount
        address user = users.naruto.account;
        assetsToDeposit = uint128(bound(assetsToDeposit,
                                         calculateMinOfSharesToStake(vaultId),
                                         fuzzVaultConfig.depositCap));

        fundUserAndDepositInVault(user, vaultId, assetsToDeposit);

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroInput.selector, "sharesAmount"));
        marketMakingEngine.initiateWithdrawal(vaultId, 0);
    }

    modifier whenAmountIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_VaultIdIsInvalid(uint256 sharesToWithdraw) external whenAmountIsNotZero {
        sharesToWithdraw = bound({ x: sharesToWithdraw, min: 1, max: type(uint128).max });

        // it should revert
        vm.expectRevert(abi.encodeWithSelector(Errors.VaultDoesNotExist.selector, INVALID_VAULT_ID));
        marketMakingEngine.initiateWithdrawal(INVALID_VAULT_ID, uint128(sharesToWithdraw));
    }

    modifier whenVaultIdIsValid() {
        _;
    }

    function testFuzz_RevertWhen_SharesAmountIsGtUserBalance(
        uint128 vaultId,
        uint128 assetsToDeposit
    )
        external
        whenAmountIsNotZero
        whenVaultIdIsValid
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

        uint128 sharesToWithdraw = IERC20(fuzzVaultConfig.indexToken).balanceOf(user).toUint128() + 1;

        // it should revert
        vm.startPrank(user);
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                user,
                sharesToWithdraw - 1,
                sharesToWithdraw
            )
        });
        marketMakingEngine.initiateWithdrawal(vaultId, sharesToWithdraw);
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
        assetsToDeposit = bound({
            x: assetsToDeposit,
            min: calculateMinOfSharesToStake(fuzzVaultConfig.vaultId),
            max: fuzzVaultConfig.depositCap
        });

        deal(fuzzVaultConfig.asset, users.naruto.account, assetsToDeposit);
        depositInVault(fuzzVaultConfig.vaultId, uint128(assetsToDeposit));

        uint128 sharesToWithdraw = IERC20(fuzzVaultConfig.indexToken).balanceOf(users.naruto.account).toUint128();

        // it should create withdraw request
        vm.expectEmit();
        emit VaultRouterBranch.LogInitiateWithdrawal(fuzzVaultConfig.vaultId, users.naruto.account, sharesToWithdraw);
        marketMakingEngine.initiateWithdrawal(fuzzVaultConfig.vaultId, sharesToWithdraw);
    }
}
