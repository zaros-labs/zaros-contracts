// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { PerpsAccount } from "@zaros/markets/perps/storage/PerpsAccount.sol";
import { ParameterError } from "@zaros/utils/Errors.sol";

contract WithdrawMargin_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function testFuzz_RevertWhen_TheAmountIsZero(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint256 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                ParameterError.Zaros_InvalidParameter.selector, "amount", "amount can't be zero"
                )
        });
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), 0);
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    function testFuzz_RevertGiven_ThereIsNotEnoughMarginAvailable(uint256 amountToDeposit)
        external
        whenTheAmountIsNotZero
        givenTheSenderIsAuthorized
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint256 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        changePrank({ msgSender: users.sasuke });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                PerpsAccount.Zaros_PerpsAccount_PermissionDenied.selector, perpsAccountId, users.sasuke
                )
        });
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), amountToDeposit);
    }

    modifier givenTheSenderIsAuthorized() {
        _;
    }

    function test_RevertGiven_ThereIsNotEnoughMarginAvailable()
        external
        whenTheAmountIsNotZero
        givenTheSenderIsAuthorized
    { }

    function testFuzz_GivenThereIsAvailableMargin(
        uint256 amountToDeposit,
        uint256 amountToWithdraw
    )
        external
        whenTheAmountIsNotZero
        givenTheSenderIsAuthorized
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        amountToWithdraw = bound({ x: amountToWithdraw, min: 1, max: amountToDeposit });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint256 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        // it should emit {LogWithdrawMargin}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogWithdrawMargin(users.naruto, perpsAccountId, address(usdToken), amountToWithdraw);

        // it should transfer the withdrawn amount to the sender
        expectCallToTransfer(usdToken, users.naruto, amountToWithdraw);
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), amountToWithdraw);

        uint256 expectedMargin = amountToDeposit - amountToWithdraw;
        uint256 newMarginCollateral =
            perpsEngine.getAccountMarginCollateralBalance(perpsAccountId, address(usdToken)).intoUint256();

        // it should decrease the amount of margin collateral
        assertEq(expectedMargin, newMarginCollateral, "withdrawMargin");
    }
}
