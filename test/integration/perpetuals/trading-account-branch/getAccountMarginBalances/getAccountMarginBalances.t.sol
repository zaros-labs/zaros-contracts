// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract getAccountMarginBreakdown_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function testFuzz_GetAccountMarginOneCollateral(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });
        deal({ token: address(usdcMarginCollateral), to: users.naruto, give: amountToDeposit });

        uint256 expectedMarginBalance = getPrice(
            MockPriceFeed(marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceFeed)
        ).mul(ud60x18(amountToDeposit)).intoUint256();
        uint256 expectedAvailableBalance = expectedMarginBalance;
        uint256 expectedInitialMargin = 0;
        uint256 expectedMaintenanceMargin = 0;
        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdcMarginCollateral));

        (
            SD59x18 marginBalanceUsdX18,
            UD60x18 initialMarginUsdX18,
            UD60x18 maintenanceMarginUsdX18,
            SD59x18 availableBalance
        ) = perpsEngine.getAccountMarginBreakdown({ tradingAccountId: tradingAccountId });

        assertEq(marginBalanceUsdX18.intoUint256(), expectedMarginBalance, "getAccountMargin marginBalanceUsdX18");
        assertEq(availableBalance.intoUint256(), expectedAvailableBalance, "getAccountMargin availableBalance");
        assertEq(initialMarginUsdX18.intoUint256(), expectedInitialMargin, "getAccountMargin initialMarginUsdX18");
        assertEq(
            maintenanceMarginUsdX18.intoUint256(),
            expectedMaintenanceMargin,
            "getAccountMargin maintenanceMarginUsdX18"
        );
    }

    function testFuzz_GetAccountMarginMultipleCollateral(
        uint256 amountToDepositUsdc,
        uint256 amountToDepositWstEth
    )
        external
    {
        amountToDepositUsdc = bound({ x: amountToDepositUsdc, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });
        amountToDepositWstEth =
            bound({ x: amountToDepositWstEth, min: WSTETH_MIN_DEPOSIT_MARGIN, max: WSTETH_DEPOSIT_CAP });

        deal({ token: address(usdcMarginCollateral), to: users.naruto, give: amountToDepositUsdc });
        deal({ token: address(wstEthMarginCollateral), to: users.naruto, give: amountToDepositWstEth });

        uint256 expectedMarginBalance = getPrice(
            MockPriceFeed(marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceFeed)
        ).mul(ud60x18(amountToDepositUsdc)).add(
            getPrice(MockPriceFeed(marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].priceFeed)).mul(
                ud60x18(amountToDepositWstEth)
            ).mul(ud60x18(WSTETH_LOAN_TO_VALUE))
        ).intoUint256();

        uint256 expectedAvailableBalance = expectedMarginBalance;
        uint256 expectedInitialMargin = 0;
        uint256 expectedMaintenanceMargin = 0;
        uint128 tradingAccountId = createAccountAndDeposit(amountToDepositUsdc, address(usdcMarginCollateral));
        perpsEngine.depositMargin(tradingAccountId, address(wstEthMarginCollateral), amountToDepositWstEth);

        (
            SD59x18 marginBalanceUsdX18,
            UD60x18 initialMarginUsdX18,
            UD60x18 maintenanceMarginUsdX18,
            SD59x18 availableBalance
        ) = perpsEngine.getAccountMarginBreakdown({ tradingAccountId: tradingAccountId });

        assertEq(marginBalanceUsdX18.intoUint256(), expectedMarginBalance, "getAccountMargin marginBalanceUsdX18");
        assertEq(availableBalance.intoUint256(), expectedAvailableBalance, "getAccountMargin availableBalance");
        assertEq(initialMarginUsdX18.intoUint256(), expectedInitialMargin, "getAccountMargin initialMarginUsdX18");
        assertEq(
            maintenanceMarginUsdX18.intoUint256(),
            expectedMaintenanceMargin,
            "getAccountMargin maintenanceMarginUsdX18"
        );
    }
}
