// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, convert as ud60x18Convert } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

contract WithdrawMarginUsd_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_WhenTheMarginCollateralBalanceUsdIsGreatherThanOrEqualToTheRequiredMarginCollateral(
        uint256 amountToDeposit,
        uint256 amountToWithdrawUsd,
        uint256 marginCollateralPriceUsd
    )
        external
    {
        // Test with wstEth that has 18 decimals

        amountToDeposit = bound({ x: amountToDeposit, min: WSTETH_MIN_DEPOSIT_MARGIN, max: WSTETH_DEPOSIT_CAP_X18 });

        // to prevent overflow when convert to ud60x18
        marginCollateralPriceUsd = bound({ x: amountToWithdrawUsd, min: 1, max: 100_000_000 });

        vm.assume(amountToDeposit >= amountToWithdrawUsd / marginCollateralPriceUsd);

        UD60x18 marginCollateralPriceUsdX18 = ud60x18Convert(marginCollateralPriceUsd);
        UD60x18 amountToWithdrawUsdX18 = ud60x18(amountToWithdrawUsd);

        assertEq(MockERC20(address(wstEth)).balanceOf(users.naruto), 0, "initial balance should be zero");
        deal({ token: address(wstEth), to: users.naruto, give: amountToDeposit });
        assertEq(MockERC20(address(wstEth)).balanceOf(users.naruto), amountToDeposit, "balanceOf is not correct");

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(wstEth));
        assertEq(MockERC20(address(wstEth)).balanceOf(users.naruto), 0, "balanceOf should be zero");

        (UD60x18 withdrawnMarginUsdX18, bool isMissingMargin) = perpsEngine.exposed_withdrawMarginUsd(
            tradingAccountId, address(wstEth), marginCollateralPriceUsdX18, amountToWithdrawUsdX18, users.naruto
        );

        // it should withdraw required margin collateral
        UD60x18 expectedBalance = amountToWithdrawUsdX18.div(marginCollateralPriceUsdX18);
        assertEq(
            MockERC20(address(wstEth)).balanceOf(users.naruto),
            expectedBalance.intoUint256(),
            "balanceOf is not correct after withdrawMarginUsd"
        );

        // it should return the required margin collateral
        assertEq(
            amountToWithdrawUsd,
            withdrawnMarginUsdX18.intoUint256(),
            "withdrawnMarginUsdX18 should be equal to amountToWithdraw"
        );

        // it should return isMissingMargin as false
        assertEq(false, isMissingMargin, "isMissingMargin should be false");

        // Test with usdc that has 6 decimals

        amountToDeposit = bound({
            x: amountToDeposit,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        amountToWithdrawUsdX18 = ud60x18(amountToWithdrawUsd);

        vm.assume(amountToDeposit >= amountToWithdrawUsd / marginCollateralPriceUsd);

        assertEq(MockERC20((usdc)).balanceOf(users.naruto), 0, "initial balance should be zero");
        deal({ token: address(usdc), to: users.naruto, give: amountToDeposit });
        assertEq(MockERC20((usdc)).balanceOf(users.naruto), amountToDeposit, "balanceOf is not correct");

        tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdc));
        assertEq(MockERC20((usdc)).balanceOf(users.naruto), 0, "balanceOf should be zero");

        (withdrawnMarginUsdX18, isMissingMargin) = perpsEngine.exposed_withdrawMarginUsd(
            tradingAccountId, address(usdc), marginCollateralPriceUsdX18, amountToWithdrawUsdX18, users.naruto
        );

        // it should withdraw required margin collateral
        expectedBalance = amountToWithdrawUsdX18.div(marginCollateralPriceUsdX18);
        assertEq(
            MockERC20((usdc)).balanceOf(users.naruto),
            expectedBalance.intoUint256(),
            "balanceOf is not correct after withdrawMarginUsd"
        );

        // it should return the required margin collateral
        assertEq(
            amountToWithdrawUsd,
            withdrawnMarginUsdX18.intoUint256(),
            "withdrawnMarginUsdX18 should be equal to amountToWithdraw"
        );

        // it should return isMissingMargin as false
        assertEq(false, isMissingMargin, "isMissingMargin should be false");
    }

    function testFuzz_WhenTheMarginCollateralBalanceUsdIsSmallerThanTheRequiredMarginCollateral(
        uint256 amountToDeposit,
        uint256 amountToWithdrawUsd,
        uint256 marginCollateralPriceUsd
    )
        external
    {
        // Test with wstEth that has 18 decimals

        amountToDeposit = bound({ x: amountToDeposit, min: WSTETH_MIN_DEPOSIT_MARGIN, max: WSTETH_DEPOSIT_CAP_X18 });

        // to prevent overflow when convert to ud60x18
        marginCollateralPriceUsd = bound({ x: amountToWithdrawUsd, min: 1, max: 100_000_000 });

        vm.assume(amountToWithdrawUsd / marginCollateralPriceUsd > amountToDeposit);

        UD60x18 marginCollateralPriceUsdX18 = ud60x18Convert(marginCollateralPriceUsd);
        UD60x18 amountToWithdrawUsdX18 = ud60x18(amountToWithdrawUsd);

        assertEq(MockERC20(address(wstEth)).balanceOf(users.naruto), 0, "initial balance should be zero");
        deal({ token: address(wstEth), to: users.naruto, give: amountToDeposit });
        assertEq(MockERC20(address(wstEth)).balanceOf(users.naruto), amountToDeposit, "balanceOf is not correct");

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(wstEth));
        assertEq(MockERC20(address(wstEth)).balanceOf(users.naruto), 0, "balanceOf should be zero");

        (UD60x18 withdrawnMarginUsdX18, bool isMissingMargin) = perpsEngine.exposed_withdrawMarginUsd(
            tradingAccountId, address(wstEth), marginCollateralPriceUsdX18, amountToWithdrawUsdX18, users.naruto
        );

        // it should withdraw margin collateral balance usd
        assertEq(
            MockERC20(address(wstEth)).balanceOf(users.naruto),
            amountToDeposit,
            "balanceOf is not correct after withdrawMarginUsd"
        );

        // it should return the margin collateral balance usd
        UD60x18 expectedWithdrawMarginUsdX18 = ud60x18(amountToDeposit).mul(marginCollateralPriceUsdX18);
        assertEq(
            expectedWithdrawMarginUsdX18.intoUint256(),
            withdrawnMarginUsdX18.intoUint256(),
            "withdrawnMarginUsdX18 is not correct"
        );

        // it should return isMissingMargin as true
        assertEq(true, isMissingMargin, "isMissingMargin should be true");

        // Test with usdc that has 6 decimals

        amountToDeposit = bound({
            x: amountToDeposit,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        // to prevent overflow when convert to ud60x18
        marginCollateralPriceUsd = bound({ x: amountToWithdrawUsd, min: 1, max: 100_000_000 });

        vm.assume(amountToWithdrawUsd / marginCollateralPriceUsd > amountToDeposit);

        marginCollateralPriceUsdX18 = ud60x18Convert(marginCollateralPriceUsd);
        amountToWithdrawUsdX18 = ud60x18(amountToWithdrawUsd);

        assertEq(MockERC20(usdc).balanceOf(users.naruto), 0, "initial balance should be zero");
        deal({ token: address(usdc), to: users.naruto, give: amountToDeposit });
        assertEq(MockERC20(address(usdc)).balanceOf(users.naruto), amountToDeposit, "balanceOf is not correct");

        tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdc));
        assertEq(MockERC20(address(usdc)).balanceOf(users.naruto), 0, "balanceOf should be zero");

        (withdrawnMarginUsdX18, isMissingMargin) = perpsEngine.exposed_withdrawMarginUsd(
            tradingAccountId, address(usdc), marginCollateralPriceUsdX18, amountToWithdrawUsdX18, users.naruto
        );

        // it should withdraw margin collateral balance usd
        assertEq(
            MockERC20(usdc).balanceOf(users.naruto),
            amountToDeposit,
            "balanceOf is not correct after withdrawMarginUsd"
        );

        // it should return the margin collateral balance usd
        expectedWithdrawMarginUsdX18 = ud60x18(amountToDeposit).mul(marginCollateralPriceUsdX18);
        assertEq(
            expectedWithdrawMarginUsdX18.intoUint256(),
            withdrawnMarginUsdX18.intoUint256(),
            "withdrawnMarginUsdX18 is not correct"
        );

        // it should return isMissingMargin as true
        assertEq(true, isMissingMargin, "isMissingMargin should be true");
    }
}
