// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// PRB Math dependencies
import { ud60x18, ZERO as UD_ZERO } from "@prb-math/UD60x18.sol";

contract WithdrawMargin_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertGiven_TheAccountDoesNotExist(uint128 perpsAccountId) external {
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, perpsAccountId, users.naruto)
        });
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), UD_ZERO);
    }

    modifier givenTheAccountExists() {
        _;
    }

    function test_RevertGiven_TheSenderIsNotAuthorized() external givenTheAccountExists {
        // it should revert
    }

    function testFuzz_RevertGiven_TheSenderIsNotAuthorized(
        uint256 amountToDeposit,
        uint256 amountToWithdraw
    )
        external
        givenTheAccountExists
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        amountToWithdraw = bound({ x: amountToWithdraw, min: 1, max: amountToDeposit });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));
        changePrank({ msgSender: users.sasuke });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.AccountPermissionDenied.selector, perpsAccountId, users.sasuke) });
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), ud60x18(amountToWithdraw));
    }

    modifier givenTheSenderIsAuthorized() {
        _;
    }

    function testFuzz_RevertWhen_TheAmountIsZero(uint256 amountToDeposit)
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), UD_ZERO);
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    function testFuzz_RevertGiven_ThereIsntEnoughMarginCollateral(
        uint256 amountToDeposit,
        uint256 amountToWithdraw
    )
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        vm.assume(amountToWithdraw > amountToDeposit);
        uint256 expectedMarginCollateralBalance =
            convertTokenAmountToUd60x18(address(usdToken), amountToDeposit).intoUint256();
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InsufficientMarginCollateralBalance.selector, amountToWithdraw, expectedMarginCollateralBalance
                )
        });
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), ud60x18(amountToWithdraw));
    }

    modifier givenThereIsEnoughMarginCollateral() {
        _;
    }

    function testFuzz_RevertGiven_TheAccountWontMeetTheMarginRequirements()
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
        givenThereIsEnoughMarginCollateral
    {
        // it should revert
    }

    function testFuzz_GivenTheAccountMeetsTheMarginRequirements(
        uint256 amountToDeposit,
        uint256 amountToWithdraw
    )
        external
        givenTheAccountExists
        givenTheSenderIsAuthorized
        whenTheAmountIsNotZero
        givenThereIsEnoughMarginCollateral
    {
        // amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        // amountToWithdraw = bound({ x: amountToWithdraw, min: 1, max: amountToDeposit });
        // deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        // uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        // // it should emit a {LogWithdrawMargin} event
        // vm.expectEmit({ emitter: address(perpsEngine) });
        // emit LogWithdrawMargin(users.naruto, perpsAccountId, address(usdToken), amountToWithdraw);

        // // it should transfer the withdrawn amount to the sender
        // expectCallToTransfer(usdToken, users.naruto, amountToWithdraw);
        // perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), ud60x18(amountToWithdraw));

        // uint256 expectedMargin = amountToDeposit - amountToWithdraw;
        // uint256 newMarginCollateralBalance =
        //     perpsEngine.getAccountMarginCollateralBalance(perpsAccountId, address(usdToken)).intoUint256();

        // // it should decrease the margin collateral balance
        // assertEq(expectedMargin, newMarginCollateralBalance, "withdrawMargin");
    }
}
