// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract DepositMargin_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function testFuzz_RevertGiven_TheCollateralTypeHasInsufficientDepositCap(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        changePrank({ msgSender: users.owner });
        perpsEngine.configureMarginCollateral(address(usdToken), 0, address(mockUsdcUsdPriceFeed));
        changePrank({ msgSender: users.naruto });

        uint128 userPerpsAccountId = perpsEngine.createPerpsAccount();

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.DepositCap.selector, address(usdToken), amountToDeposit, 0)
        });

        perpsEngine.depositMargin(userPerpsAccountId, address(usdToken), amountToDeposit);
    }

    modifier givenTheCollateralTypeHasSufficientDepositCap() {
        _;
    }

    function test_RevertWhen_TheAmountIsZero() external givenTheCollateralTypeHasSufficientDepositCap {
        uint256 amountToDeposit = 0;
        uint128 userPerpsAccountId = perpsEngine.createPerpsAccount();

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });

        perpsEngine.depositMargin(userPerpsAccountId, address(usdToken), amountToDeposit);
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    function testFuzz_RevertGiven_ThePerpsAccountDoesNotExist(
        uint128 userPerpsAccountId,
        uint256 amountToDeposit
    )
        external
        givenTheCollateralTypeHasSufficientDepositCap
        whenTheAmountIsNotZero
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, userPerpsAccountId, users.naruto)
        });

        perpsEngine.depositMargin(userPerpsAccountId, address(usdToken), amountToDeposit);
    }

    function testFuzz_GivenThePerpsAccountExists(uint256 amountToDeposit)
        external
        givenTheCollateralTypeHasSufficientDepositCap
        whenTheAmountIsNotZero
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint128 userPerpsAccountId = perpsEngine.createPerpsAccount();

        // it should emit {LogDepositMargin}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogDepositMargin(users.naruto, userPerpsAccountId, address(usdToken), amountToDeposit);

        // it should transfer the amount from the sender to the perps account
        expectCallToTransferFrom(usdToken, users.naruto, address(perpsEngine), amountToDeposit);
        perpsEngine.depositMargin(userPerpsAccountId, address(usdToken), amountToDeposit);

        uint256 newMarginCollateralBalance =
            perpsEngine.getAccountMarginCollateralBalance(userPerpsAccountId, address(usdToken)).intoUint256();

        // it should increase the amount of margin collateral
        assertEq(newMarginCollateralBalance, amountToDeposit, "depositMargin");
    }
}
