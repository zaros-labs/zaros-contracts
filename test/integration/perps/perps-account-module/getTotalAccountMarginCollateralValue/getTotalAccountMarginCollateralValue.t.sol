// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract GetTotalAccountMarginCollateralValue_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function testFuzz_GetTotalAccountMarginCollateralValueOneCollateral(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint256 expectedMarginCollateralValue =
            getPrice(mockUsdcUsdPriceFeed).mul(ud60x18(amountToDeposit)).intoUint256();
        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        uint256 marginCollateralValue =
            perpsEngine.getTotalAccountMarginCollateralValue({ accountId: perpsAccountId }).intoUint256();

        assertEq(marginCollateralValue, expectedMarginCollateralValue, "getTotalAccountMarginCollateralValue");
    }

    function testFuzz_GetTotalAccountMarginCollateralValueMultipleCollateral(uint256 amountToDeposit) external {
        // TODO: let's fuzz the tokens used here
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: WSTETH_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });
        deal({ token: address(mockWstEth), to: users.naruto, give: amountToDeposit });

        uint256 expectedMarginCollateralValue = getPrice(mockUsdcUsdPriceFeed).mul(ud60x18(amountToDeposit)).add(
            getPrice(mockWstEthUsdPriceFeed).mul(ud60x18(amountToDeposit))
        ).intoUint256();
        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));
        perpsEngine.depositMargin(perpsAccountId, address(mockWstEth), amountToDeposit);

        uint256 marginCollateralValue =
            perpsEngine.getTotalAccountMarginCollateralValue({ accountId: perpsAccountId }).intoUint256();

        assertEq(marginCollateralValue, expectedMarginCollateralValue, "getTotalAccountMarginCollateralValue");
    }
}
