// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract getAccountEquityUsd_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function testFuzz_getAccountEquityUsdOneCollateral(uint256 amountToDeposit, uint256 marketId) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        FuzzMarginPortfolio memory fuzzMarginPortfolio = getFuzzMarginPortfolio(fuzzMarketConfig, 0, amountToDeposit);

        uint256 expectedMarginCollateralValue =
            getPrice(mockPriceAdapters.mockUsdcUsdPriceAdapter).mul(ud60x18(fuzzMarginPortfolio.marginValueUsd)).intoUint256();
        uint128 perpsAccountId = createAccountAndDeposit(fuzzMarginPortfolio.marginValueUsd, address(usdToken));

        uint256 marginCollateralValue = perpsEngine.getAccountEquityUsd({ accountId: perpsAccountId }).intoUint256();

        assertEq(marginCollateralValue, expectedMarginCollateralValue, "getAccountEquityUsd");
    }

    function testFuzz_getAccountEquityUsdMultipleCollateral(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: WSTETH_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });
        deal({ token: address(mockWstEth), to: users.naruto, give: amountToDeposit });

        uint256 expectedMarginCollateralValue = getPrice(mockPriceAdapters.mockUsdcUsdPriceAdapter).mul(
            ud60x18(amountToDeposit)
        ).add(getPrice(mockPriceAdapters.mockWstEthUsdPriceAdapter).mul(ud60x18(amountToDeposit))).intoUint256();
        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));
        perpsEngine.depositMargin(perpsAccountId, address(mockWstEth), amountToDeposit);

        uint256 marginCollateralValue = perpsEngine.getAccountEquityUsd({ accountId: perpsAccountId }).intoUint256();

        assertEq(marginCollateralValue, expectedMarginCollateralValue, "getAccountEquityUsd");
    }
}
