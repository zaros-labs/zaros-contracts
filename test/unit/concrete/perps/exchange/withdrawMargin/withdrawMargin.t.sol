// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { PerpsAccount } from "@zaros/markets/perps/storage/PerpsAccount.sol";
import { ParameterError } from "@zaros/utils/Errors.sol";

contract WithdrawMargin_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        approveContracts();
        changePrank({ msgSender: users.naruto });
    }

    function test_AmountZero() external {
        uint256 amount = 100e18;
        uint256 perpsAccountId = _createAccountAndDeposit(amount);

        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                ParameterError.Zaros_InvalidParameter.selector, "amount", "amount can't be zero"
                )
        });
        perpsExchange.withdrawMargin(perpsAccountId, address(usdToken), 0);
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
        perpsExchange.withdrawMargin(perpsAccountId, address(usdToken), amount);
    }

    modifier whenAuthorizedSender() {
        _;
    }

    function test_NotEnoughMarginAvailable() external whenAmountIsNotZero whenAuthorizedSender { }

    function test_EnoughMarginAvailable() external whenAmountIsNotZero whenAuthorizedSender {
        uint256 amount = 100e18;
        uint256 amountToWithdraw = 50e18;
        uint256 perpsAccountId = _createAccountAndDeposit(amount);

        vm.expectEmit({ emitter: address(perpsExchange) });
        emit LogWithdrawMargin(users.naruto, perpsAccountId, address(usdToken), amountToWithdraw);
        expectCallToTransfer(usdToken, users.naruto, amountToWithdraw);
        perpsExchange.withdrawMargin(perpsAccountId, address(usdToken), amountToWithdraw);

        uint256 expectedMargin = amount - amountToWithdraw;
        uint256 newMarginCollateral =
            perpsExchange.getAccountMarginCollateral(perpsAccountId, address(usdToken)).intoUint256();

        assertEq(expectedMargin, newMarginCollateral);
    }

    function _createAccountAndDeposit(uint256 amount) internal returns (uint256 accountId) {
        accountId = perpsExchange.createPerpsAccount();
        perpsExchange.depositMargin(accountId, address(usdToken), amount);
    }
}
