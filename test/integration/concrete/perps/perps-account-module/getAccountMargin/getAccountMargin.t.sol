// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract GetAccountMargin_Integration_Concrete_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function test_GetAccountMarginOneCollateral() external {
        uint256 amount = 100e18;
        uint256 expectedMarginBalance = _getPrice(mockUsdcUsdPriceFeed).mul(ud60x18(amount)).intoUint256();
        uint256 expectedAvailableBalance = expectedMarginBalance;
        uint256 expectedInitialMargin = 0;
        uint256 expectedMaintenanceMargin = 0;
        uint256 perpsAccountId = _createAccountAndDeposit(amount, address(usdToken));

        (SD59x18 marginBalance, SD59x18 availableBalance, UD60x18 initialMargin, UD60x18 maintenanceMargin) =
            perpsEngine.getAccountMargin({ accountId: perpsAccountId });

        assertEq(marginBalance.intoUint256(), expectedMarginBalance, "getAccountMargin marginBalance");
        assertEq(availableBalance.intoUint256(), expectedAvailableBalance, "getAccountMargin availableBalance");
        assertEq(initialMargin.intoUint256(), expectedInitialMargin, "getAccountMargin initialMargin");
        assertEq(maintenanceMargin.intoUint256(), expectedMaintenanceMargin, "getAccountMargin maintenanceMargin");
    }

    function test_GetAccountMarginMultipleCollateral() external {
        uint256 amount = 100e18;
        uint256 expectedMarginBalance = _getPrice(mockUsdcUsdPriceFeed).mul(ud60x18(amount)).add(
            _getPrice(mockWstEthUsdPriceFeed).mul(ud60x18(amount))
        ).intoUint256();
        uint256 expectedAvailableBalance = expectedMarginBalance;
        uint256 expectedInitialMargin = 0;
        uint256 expectedMaintenanceMargin = 0;
        uint256 perpsAccountId = _createAccountAndDeposit(amount, address(usdToken));
        perpsEngine.depositMargin(perpsAccountId, address(mockWstEth), amount);

        (SD59x18 marginBalance, SD59x18 availableBalance, UD60x18 initialMargin, UD60x18 maintenanceMargin) =
            perpsEngine.getAccountMargin({ accountId: perpsAccountId });

        assertEq(marginBalance.intoUint256(), expectedMarginBalance, "getAccountMargin marginBalance");
        assertEq(availableBalance.intoUint256(), expectedAvailableBalance, "getAccountMargin availableBalance");
        assertEq(initialMargin.intoUint256(), expectedInitialMargin, "getAccountMargin initialMargin");
        assertEq(maintenanceMargin.intoUint256(), expectedMaintenanceMargin, "getAccountMargin maintenanceMargin");
    }
}
