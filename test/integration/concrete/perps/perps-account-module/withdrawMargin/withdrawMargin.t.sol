// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { PerpsAccountModule_Integration_Shared_Test } from
    "test/integration/shared/perps-account-module/PerpsAccountModule.t.sol";
import { PerpsAccount } from "@zaros/markets/perps/storage/PerpsAccount.sol";
import { ParameterError } from "@zaros/utils/Errors.sol";

contract WithdrawMargin_Integration_Concrete_Test is PerpsAccountModule_Integration_Shared_Test {
    function setUp() public override {
        PerpsAccountModule_Integration_Shared_Test.setUp();
    }

    function test_AmountZero() external {
        uint256 amount = 100e18;
        uint256 perpsAccountId = _createAccountAndDeposit(amount);

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

    function test_UnauthorizedSender() external whenAmountIsNotZero {
        uint256 amount = 100e18;
        uint256 perpsAccountId = _createAccountAndDeposit(amount);

        changePrank({ msgSender: users.sasuke });
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                PerpsAccount.Zaros_PerpsAccount_PermissionDenied.selector, perpsAccountId, users.sasuke
                )
        });
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), amount);
    }

    modifier whenAuthorizedSender() {
        _;
    }

    function test_NotEnoughMarginAvailable() external whenAmountIsNotZero whenAuthorizedSender { }

    function test_EnoughMarginAvailable() external whenAmountIsNotZero whenAuthorizedSender {
        uint256 amount = 100e18;
        uint256 amountToWithdraw = 50e18;
        uint256 perpsAccountId = _createAccountAndDeposit(amount);

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogWithdrawMargin(users.naruto, perpsAccountId, address(usdToken), amountToWithdraw);
        expectCallToTransfer(usdToken, users.naruto, amountToWithdraw);
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), amountToWithdraw);

        uint256 expectedMargin = amount - amountToWithdraw;
        uint256 newMarginCollateral =
            perpsEngine.getAccountMarginCollateral(perpsAccountId, address(usdToken)).intoUint256();

        assertEq(expectedMargin, newMarginCollateral);
    }
}
