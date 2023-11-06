// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

/// TODO: add margin caps to fix these tests
contract GetTotalAccountMarginCollateralValue_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function testFuzz_GetTotalAccountMarginCollateralValueOneCollateral(uint256 amountToDeposit) external {
        vm.assume({ condition: amountToDeposit > 0 });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint256 expectedMarginCollateralValue =
            getPrice(mockUsdcUsdPriceFeed).mul(ud60x18(amountToDeposit)).intoUint256();
        uint256 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        uint256 marginCollateralValue =
            perpsEngine.getTotalAccountMarginCollateralValue({ accountId: perpsAccountId }).intoUint256();

        assertEq(marginCollateralValue, expectedMarginCollateralValue, "getTotalAccountMarginCollateralValue");
    }

    function testFuzz_GetTotalAccountMarginCollateralValueMultipleCollateral(uint256 amountToDeposit) external {
        vm.assume({ condition: amountToDeposit > 0 });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });
        deal({ token: address(mockWstEth), to: users.naruto, give: amountToDeposit });

        uint256 expectedMarginCollateralValue = getPrice(mockUsdcUsdPriceFeed).mul(ud60x18(amountToDeposit)).add(
            getPrice(mockWstEthUsdPriceFeed).mul(ud60x18(amountToDeposit))
        ).intoUint256();
        uint256 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));
        perpsEngine.depositMargin(perpsAccountId, address(mockWstEth), amountToDeposit);

        uint256 marginCollateralValue =
            perpsEngine.getTotalAccountMarginCollateralValue({ accountId: perpsAccountId }).intoUint256();

        assertEq(marginCollateralValue, expectedMarginCollateralValue, "getTotalAccountMarginCollateralValue");
    }
}
