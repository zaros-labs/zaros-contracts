// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract getAccountEquityUsd_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function testFuzz_getAccountEquityUsdOneCollateral(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: USDC_MIN_DEPOSIT_MARGIN, max: USDC_DEPOSIT_CAP });
        deal({ token: address(usdcMarginCollateral), to: users.naruto, give: amountToDeposit });

        uint256 expectedMarginCollateralValue = getPrice(
            MockPriceFeed(marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceFeed)
        ).mul(ud60x18(amountToDeposit)).intoUint256();

        uint128 tradingAccountId = createAccountAndDeposit(amountToDeposit, address(usdcMarginCollateral));

        uint256 marginCollateralValue =
            perpsEngine.getAccountEquityUsd({ tradingAccountId: tradingAccountId }).intoUint256();

        assertEq(marginCollateralValue, expectedMarginCollateralValue, "getAccountEquityUsd");
    }

    function testFuzz_getAccountEquityUsdMultipleCollateral(
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

        uint256 expectedMarginCollateralValue = getPrice(
            MockPriceFeed(marginCollaterals[USDC_MARGIN_COLLATERAL_ID].priceFeed)
        ).mul(ud60x18(amountToDepositUsdc)).add(
            getPrice(MockPriceFeed(marginCollaterals[WSTETH_MARGIN_COLLATERAL_ID].priceFeed)).mul(
                ud60x18(amountToDepositWstEth)
            )
        ).intoUint256();

        uint128 tradingAccountId = createAccountAndDeposit(amountToDepositUsdc, address(usdcMarginCollateral));

        perpsEngine.depositMargin(tradingAccountId, address(wstEthMarginCollateral), amountToDepositWstEth);

        uint256 marginCollateralValue =
            perpsEngine.getAccountEquityUsd({ tradingAccountId: tradingAccountId }).intoUint256();

        assertEq(marginCollateralValue, expectedMarginCollateralValue, "getAccountEquityUsd");
    }
}
