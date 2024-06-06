// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";

contract DepositMargin_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_RevertWhen_TheAmountIsZero() external {
        uint256 amountToDeposit = 0;
        uint128 userTradingAccountId = perpsEngine.createTradingAccount();

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });

        perpsEngine.depositMargin(userTradingAccountId, address(usdToken), amountToDeposit);
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

        uint128 userTradingAccountId = perpsEngine.createTradingAccount();

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.DepositCap.selector, address(usdToken), amountToDeposit, 0)
        });

        perpsEngine.depositMargin(userTradingAccountId, address(usdToken), amountToDeposit);
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

        uint128 userTradingAccountId = perpsEngine.createTradingAccount();

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.CollateralLiquidationPriorityNotDefined.selector, address(usdToken))
        });
        perpsEngine.depositMargin(userTradingAccountId, address(usdToken), amountToDeposit);
    }

    modifier givenTheCollateralTypeIsInTheLiquidationPriority() {
        _;
    }

    function testFuzz_RevertGiven_TheTradingAccountDoesNotExist(
        uint128 userTradingAccountId,
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
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, userTradingAccountId, users.naruto)
        });

        perpsEngine.depositMargin(userTradingAccountId, address(usdToken), amountToDeposit);
    }

    function testFuzz_GivenTheTradingAccountExists(uint256 amountToDeposit)
        external
        whenTheAmountIsNotZero
        givenTheCollateralTypeHasSufficientDepositCap
        givenTheCollateralTypeIsInTheLiquidationPriority
    {
        // Test with usdToken that have 18 decimals

        assertEq(MockERC20(address(usdToken)).decimals(), 18, "decimals should be 18");
        assertEq(MockERC20(address(usdToken)).balanceOf(users.naruto), 0, "initial balance should be zero");

        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        assertEq(MockERC20(address(usdToken)).balanceOf(users.naruto), amountToDeposit, "balanceOf is not correct");

        uint128 userTradingAccountId = perpsEngine.createTradingAccount();

        // it should emit {LogDepositMargin}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit TradingAccountBranch.LogDepositMargin(
            users.naruto, userTradingAccountId, address(usdToken), amountToDeposit
        );

        // it should transfer the amount from the sender to the trading account
        expectCallToTransferFrom(usdToken, users.naruto, address(perpsEngine), amountToDeposit);
        perpsEngine.depositMargin(userTradingAccountId, address(usdToken), amountToDeposit);

        assertEq(MockERC20(address(usdToken)).balanceOf(users.naruto), 0, "balanceOf should be zero");

        uint256 newMarginCollateralBalance =
            perpsEngine.getAccountMarginCollateralBalance(userTradingAccountId, address(usdToken)).intoUint256();

        // it should increase the amount of margin collateral
        assertEq(newMarginCollateralBalance, amountToDeposit, "depositMargin");

        // Test with usdToken that have 10 decimals

        assertEq(MockERC20(mockUsdWith10Decimals).decimals(), 10, "decimals should be 10");
        assertEq(MockERC20(mockUsdWith10Decimals).balanceOf(users.naruto), 0, "initial balance should be zero");

        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: MOCK_USD_10_DECIMALS_DEPOSIT_CAP });
        deal({ token: address(mockUsdWith10Decimals), to: users.naruto, give: amountToDeposit });

        assertEq(
            MockERC20(mockUsdWith10Decimals).balanceOf(users.naruto), amountToDeposit, "balanceOf is not correct"
        );

        // it should emit {LogDepositMargin}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit TradingAccountBranch.LogDepositMargin(
            users.naruto, userTradingAccountId, address(mockUsdWith10Decimals), amountToDeposit
        );

        // it should transfer the amount from the sender to the trading account
        expectCallToTransferFrom(mockUsdWith10Decimals, users.naruto, address(perpsEngine), amountToDeposit);
        perpsEngine.depositMargin(userTradingAccountId, address(mockUsdWith10Decimals), amountToDeposit);

        assertEq(MockERC20(mockUsdWith10Decimals).balanceOf(users.naruto), 0, "balanceOf should be zero");

        newMarginCollateralBalance = perpsEngine.getAccountMarginCollateralBalance(
            userTradingAccountId, address(mockUsdWith10Decimals)
        ).intoUint256();

        // it should increase the amount of margin collateral
        assertEq(newMarginCollateralBalance, amountToDeposit, "depositMargin");
    }
}
