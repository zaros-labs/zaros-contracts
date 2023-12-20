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
    }

    function testFuzz_RevertWhen_TheAmountIsZero(uint256 amountToDeposit) external {
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

    function testFuzz_RevertGiven_ThereIsNotEnoughMarginAvailable(uint256 amountToDeposit)
        external
        whenTheAmountIsNotZero
        givenTheSenderIsAuthorized
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        changePrank({ msgSender: users.sasuke });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountPermissionDenied.selector, perpsAccountId, users.sasuke)
        });
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), ud60x18(amountToDeposit));
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

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        // it should emit {LogWithdrawMargin}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogWithdrawMargin(users.naruto, perpsAccountId, address(usdToken), amountToWithdraw);

        // it should transfer the withdrawn amount to the sender
        expectCallToTransfer(usdToken, users.naruto, amountToWithdraw);
        perpsEngine.withdrawMargin(perpsAccountId, address(usdToken), ud60x18(amountToWithdraw));

        uint256 expectedMargin = amountToDeposit - amountToWithdraw;
        uint256 newMarginCollateral =
            perpsEngine.getAccountMarginCollateralBalance(perpsAccountId, address(usdToken)).intoUint256();

        // it should decrease the amount of margin collateral
        assertEq(expectedMargin, newMarginCollateral, "withdrawMargin");
    }
}
