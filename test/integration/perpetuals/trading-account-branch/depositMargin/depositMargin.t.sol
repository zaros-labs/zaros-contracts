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

        perpsEngine.depositMargin(userTradingAccountId, address(usdcMarginCollateral), amountToDeposit);
    }

    modifier whenTheAmountIsNotZero() {
        _;
    }

    function testFuzz_RevertGiven_TheCollateralTypeHasInsufficientDepositCap(uint256 amountToDeposit)
        external
        whenTheAmountIsNotZero
    {
        amountToDeposit = bound({ x: amountToDeposit, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });
        deal({ token: address(usdcMarginCollateral), to: users.naruto, give: amountToDeposit });

        changePrank({ msgSender: users.owner });
        perpsEngine.configureMarginCollateral(
            address(usdcMarginCollateral),
            0,
            USDC_LOAN_TO_VALUE,
            marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceFeed
        );
        changePrank({ msgSender: users.naruto });

        uint128 userTradingAccountId = perpsEngine.createTradingAccount();

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.DepositCap.selector, address(usdcMarginCollateral), amountToDeposit, 0
            )
        });

        perpsEngine.depositMargin(userTradingAccountId, address(usdcMarginCollateral), amountToDeposit);
    }

    modifier givenTheCollateralTypeHasSufficientDepositCap() {
        _;
    }

    function testFuzz_RevertGiven_TheCollateralTypeIsNotInTheLiquidationPriority(uint256 amountToDeposit)
        external
        whenTheAmountIsNotZero
        givenTheCollateralTypeHasSufficientDepositCap
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDC_DEPOSIT_CAP });
        deal({ token: address(usdcMarginCollateral), to: users.naruto, give: amountToDeposit });

        changePrank({ msgSender: users.owner });

        perpsEngine.removeCollateralFromLiquidationPriority(address(usdcMarginCollateral));

        changePrank({ msgSender: users.naruto });

        uint128 userTradingAccountId = perpsEngine.createTradingAccount();

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.CollateralLiquidationPriorityNotDefined.selector, address(usdcMarginCollateral)
            )
        });
        perpsEngine.depositMargin(userTradingAccountId, address(usdcMarginCollateral), amountToDeposit);
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
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDC_DEPOSIT_CAP });
        deal({ token: address(usdcMarginCollateral), to: users.naruto, give: amountToDeposit });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, userTradingAccountId, users.naruto)
        });

        perpsEngine.depositMargin(userTradingAccountId, address(usdcMarginCollateral), amountToDeposit);
    }

    function testFuzz_GivenTheTradingAccountExists(uint256 amountToDeposit)
        external
        whenTheAmountIsNotZero
        givenTheCollateralTypeHasSufficientDepositCap
        givenTheCollateralTypeIsInTheLiquidationPriority
    {
        // Test with usdc that haves 18 decimals

        assertEq(
            MockERC20(address(usdcMarginCollateral)).balanceOf(users.naruto), 0, "initial balance should be zero"
        );

        amountToDeposit = bound({ x: amountToDeposit, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });
        deal({ token: address(usdcMarginCollateral), to: users.naruto, give: amountToDeposit });

        assertEq(
            MockERC20(address(usdcMarginCollateral)).balanceOf(users.naruto),
            amountToDeposit,
            "balanceOf is not correct"
        );

        uint128 userTradingAccountId = perpsEngine.createTradingAccount();

        // it should emit {LogDepositMargin}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit TradingAccountBranch.LogDepositMargin(
            users.naruto, userTradingAccountId, address(usdcMarginCollateral), amountToDeposit
        );

        // it should transfer the amount from the sender to the trading account
        expectCallToTransferFrom(usdcMarginCollateral, users.naruto, address(perpsEngine), amountToDeposit);
        perpsEngine.depositMargin(userTradingAccountId, address(usdcMarginCollateral), amountToDeposit);

        assertEq(MockERC20(address(usdcMarginCollateral)).balanceOf(users.naruto), 0, "balanceOf should be zero");

        uint256 newMarginCollateralBalance = perpsEngine.getAccountMarginCollateralBalance(
            userTradingAccountId, address(usdcMarginCollateral)
        ).intoUint256();

        // it should increase the amount of margin collateral
        assertEq(newMarginCollateralBalance, amountToDeposit, "depositMargin");

        // Test with wstEth that haves 18 decimals

        assertEq(MockERC20(wstEthMarginCollateral).balanceOf(users.naruto), 0, "initial balance should be zero");

        amountToDeposit = bound({ x: amountToDeposit, min: WSTETH_MIN_DEPOSIT_MARGIN, max: WSTETH_DEPOSIT_CAP });
        deal({ token: address(wstEthMarginCollateral), to: users.naruto, give: amountToDeposit });

        assertEq(
            MockERC20(wstEthMarginCollateral).balanceOf(users.naruto), amountToDeposit, "balanceOf is not correct"
        );

        // it should emit {LogDepositMargin}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit TradingAccountBranch.LogDepositMargin(
            users.naruto, userTradingAccountId, address(wstEthMarginCollateral), amountToDeposit
        );

        // it should transfer the amount from the sender to the trading account
        expectCallToTransferFrom(wstEthMarginCollateral, users.naruto, address(perpsEngine), amountToDeposit);
        perpsEngine.depositMargin(userTradingAccountId, address(wstEthMarginCollateral), amountToDeposit);

        assertEq(MockERC20(wstEthMarginCollateral).balanceOf(users.naruto), 0, "balanceOf should be zero");

        newMarginCollateralBalance = perpsEngine.getAccountMarginCollateralBalance(
            userTradingAccountId, address(wstEthMarginCollateral)
        ).intoUint256();

        // it should increase the amount of margin collateral
        assertEq(newMarginCollateralBalance, amountToDeposit, "depositMargin");
    }
}
