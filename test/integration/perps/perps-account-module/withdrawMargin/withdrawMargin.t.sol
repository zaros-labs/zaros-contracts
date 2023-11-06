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

    function testFuzz_AmountZero(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: ZRSUSD_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint256 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                ParameterError.Zaros_InvalidParameter.selector, "amount", "amount can't be zero"
                )
        });
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), 0);
    }

    modifier whenAmountIsNotZero() {
        _;
    }

    function testFuzz_UnauthorizedSender(uint256 amountToDeposit) external whenAmountIsNotZero {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: ZRSUSD_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint256 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        changePrank({ msgSender: users.sasuke });
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                PerpsAccount.Zaros_PerpsAccount_PermissionDenied.selector, perpsAccountId, users.sasuke
                )
        });
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), amountToDeposit);
    }

    modifier whenAuthorizedSender() {
        _;
    }

    function test_NotEnoughMarginAvailable() external whenAmountIsNotZero whenAuthorizedSender { }

    function testFuzz_EnoughMarginAvailable(
        uint256 amountToDeposit,
        uint256 amountToWithdraw
    )
        external
        whenAmountIsNotZero
        whenAuthorizedSender
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: ZRSUSD_DEPOSIT_CAP });
        amountToWithdraw = bound({ x: amountToWithdraw, min: 1, max: amountToDeposit });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint256 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogWithdrawMargin(users.naruto, perpsAccountId, address(usdToken), amountToWithdraw);
        expectCallToTransfer(usdToken, users.naruto, amountToWithdraw);
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), amountToWithdraw);

        uint256 expectedMargin = amountToDeposit - amountToWithdraw;
        uint256 newMarginCollateral =
            perpsEngine.getAccountMarginCollateral(perpsAccountId, address(usdToken)).intoUint256();

        assertEq(expectedMargin, newMarginCollateral, "withdrawMargin");
    }
}
