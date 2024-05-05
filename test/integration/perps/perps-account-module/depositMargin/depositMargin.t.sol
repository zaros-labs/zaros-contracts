// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract DepositMargin_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function test_RevertWhen_TheAmountIsZero() external {
        uint256 amountToDeposit = 0;
        uint128 userPerpsAccountId = perpsEngine.createPerpsAccount();

        uint256 quantityFuzzMarginCollateralAddress = 1;
        address[] memory fuzzMarginCollateralAddress =
            getFuzzMarginCollateralAddress(quantityFuzzMarginCollateralAddress);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });

        perpsEngine.depositMargin(userPerpsAccountId, fuzzMarginCollateralAddress[0], amountToDeposit);
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    function testFuzz_RevertGiven_TheCollateralTypeHasInsufficientDepositCap(uint256 amountToDeposit)
        external
        whenTheAmountIsNotZero
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        changePrank({ msgSender: users.owner });
        perpsEngine.configureMarginCollateral(
            address(usdToken), 0, USDZ_LOAN_TO_VALUE, address(mockPriceAdapters.mockUsdcUsdPriceAdapter)
        );
        changePrank({ msgSender: users.naruto });

        uint128 userPerpsAccountId = perpsEngine.createPerpsAccount();

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.DepositCap.selector, address(usdToken), amountToDeposit, 0)
        });

        uint256 quantityFuzzMarginCollateralAddress = 1;
        address[] memory fuzzMarginCollateralAddress =
            getFuzzMarginCollateralAddress(quantityFuzzMarginCollateralAddress);

        perpsEngine.depositMargin(userPerpsAccountId, fuzzMarginCollateralAddress[0], amountToDeposit);
    }

    modifier givenTheCollateralTypeHasSufficientDepositCap() {
        _;
    }

    function testFuzz_RevertGiven_TheCollateralTypeIsNotInTheLiquidationPriority(uint256 amountToDeposit)
        external
        whenTheAmountIsNotZero
        givenTheCollateralTypeHasSufficientDepositCap
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        changePrank({ msgSender: users.owner });

        perpsEngine.removeCollateralFromLiquidationPriority(address(usdToken));

        changePrank({ msgSender: users.naruto });

        uint128 userPerpsAccountId = perpsEngine.createPerpsAccount();

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.CollateralLiquidationPriorityNotDefined.selector, address(usdToken))
        });

        uint256 quantityFuzzMarginCollateralAddress = 1;
        address[] memory fuzzMarginCollateralAddress =
            getFuzzMarginCollateralAddress(quantityFuzzMarginCollateralAddress);

        perpsEngine.depositMargin(userPerpsAccountId, fuzzMarginCollateralAddress[0], amountToDeposit);
    }

    modifier givenTheCollateralTypeIsInTheLiquidationPriority() {
        _;
    }

    function testFuzz_RevertGiven_ThePerpsAccountDoesNotExist(
        uint128 userPerpsAccountId,
        uint256 amountToDeposit
    )
        external
        whenTheAmountIsNotZero
        givenTheCollateralTypeHasSufficientDepositCap
        givenTheCollateralTypeIsInTheLiquidationPriority
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, userPerpsAccountId, users.naruto)
        });

        uint256 quantityFuzzMarginCollateralAddress = 1;
        address[] memory fuzzMarginCollateralAddress =
            getFuzzMarginCollateralAddress(quantityFuzzMarginCollateralAddress);

        perpsEngine.depositMargin(userPerpsAccountId, fuzzMarginCollateralAddress[0], amountToDeposit);
    }

    function testFuzz_GivenThePerpsAccountExists(uint256 amountToDeposit)
        external
        whenTheAmountIsNotZero
        givenTheCollateralTypeHasSufficientDepositCap
        givenTheCollateralTypeIsInTheLiquidationPriority
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint128 userPerpsAccountId = perpsEngine.createPerpsAccount();

        // it should emit {LogDepositMargin}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogDepositMargin(users.naruto, userPerpsAccountId, address(usdToken), amountToDeposit);

        // it should transfer the amount from the sender to the perps account
        expectCallToTransferFrom(usdToken, users.naruto, address(perpsEngine), amountToDeposit);

        uint256 quantityFuzzMarginCollateralAddress = 1;
        address[] memory fuzzMarginCollateralAddress =
            getFuzzMarginCollateralAddress(quantityFuzzMarginCollateralAddress);

        perpsEngine.depositMargin(userPerpsAccountId, fuzzMarginCollateralAddress[0], amountToDeposit);

        uint256 newMarginCollateralBalance =
            perpsEngine.getAccountMarginCollateralBalance(userPerpsAccountId, address(usdToken)).intoUint256();

        // it should increase the amount of margin collateral
        assertEq(newMarginCollateralBalance, amountToDeposit, "depositMargin");
    }
}
