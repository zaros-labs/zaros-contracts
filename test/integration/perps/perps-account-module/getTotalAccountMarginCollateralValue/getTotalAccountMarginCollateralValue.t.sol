// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract GetTotalAccountMarginCollateralValue_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function test_GetTotalAccountMarginCollateralValueOneCollateral() external {
        uint256 amount = 100e18;
        uint256 expectedMarginCollateralValue = _getPrice(mockUsdcUsdPriceFeed).mul(ud60x18(amount)).intoUint256();
        uint256 perpsAccountId = _createAccountAndDeposit(amount, address(usdToken));

        uint256 marginCollateralValue =
            perpsEngine.getTotalAccountMarginCollateralValue({ accountId: perpsAccountId }).intoUint256();

        assertEq(marginCollateralValue, expectedMarginCollateralValue, "getTotalAccountMarginCollateralValue");
    }

    function test_GetTotalAccountMarginCollateralValueMultipleCollateral() external {
        uint256 amount = 100e18;
        uint256 expectedMarginCollateralValue = _getPrice(mockUsdcUsdPriceFeed).mul(ud60x18(amount)).add(
            _getPrice(mockWstEthUsdPriceFeed).mul(ud60x18(amount))
        ).intoUint256();
        uint256 perpsAccountId = _createAccountAndDeposit(amount, address(usdToken));
        perpsEngine.depositMargin(perpsAccountId, address(mockWstEth), amount);

        uint256 marginCollateralValue =
            perpsEngine.getTotalAccountMarginCollateralValue({ accountId: perpsAccountId }).intoUint256();

        assertEq(marginCollateralValue, expectedMarginCollateralValue, "getTotalAccountMarginCollateralValue");
    }
}
