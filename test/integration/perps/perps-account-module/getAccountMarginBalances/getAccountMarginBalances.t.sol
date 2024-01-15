// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract getAccountMarginBreakdown_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function testFuzz_GetAccountMarginOneCollateral(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint256 expectedMarginBalance = getPrice(mockUsdcUsdPriceAdapter).mul(ud60x18(amountToDeposit)).intoUint256();
        uint256 expectedAvailableBalance = expectedMarginBalance;
        uint256 expectedInitialMargin = 0;
        uint256 expectedMaintenanceMargin = 0;
        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        uint128[] memory activeMarketsIds;
        UD60x18[] memory indexPricesX18;

        (
            SD59x18 marginBalanceUsdX18,
            UD60x18 initialMarginUsdX18,
            UD60x18 maintenanceMarginUsdX18,
            SD59x18 availableBalance
        ) = perpsEngine.getAccountMarginBreakdown({
            accountId: perpsAccountId,
            activeMarketsIds: activeMarketsIds,
            indexPricesX18: indexPricesX18
        });

        assertEq(marginBalanceUsdX18.intoUint256(), expectedMarginBalance, "getAccountMargin marginBalanceUsdX18");
        assertEq(availableBalance.intoUint256(), expectedAvailableBalance, "getAccountMargin availableBalance");
        assertEq(initialMarginUsdX18.intoUint256(), expectedInitialMargin, "getAccountMargin initialMarginUsdX18");
        assertEq(
            maintenanceMarginUsdX18.intoUint256(),
            expectedMaintenanceMargin,
            "getAccountMargin maintenanceMarginUsdX18"
        );
    }

    function testFuzz_GetAccountMarginMultipleCollateral(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: WSTETH_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });
        deal({ token: address(mockWstEth), to: users.naruto, give: amountToDeposit });

        uint256 expectedMarginBalance = getPrice(mockUsdcUsdPriceAdapter).mul(ud60x18(amountToDeposit)).add(
            getPrice(mockWstEthUsdPriceAdapter).mul(ud60x18(amountToDeposit))
        ).intoUint256();
        uint256 expectedAvailableBalance = expectedMarginBalance;
        uint256 expectedInitialMargin = 0;
        uint256 expectedMaintenanceMargin = 0;
        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));
        perpsEngine.depositMargin(perpsAccountId, address(mockWstEth), amountToDeposit);

        uint128[] memory activeMarketsIds;
        UD60x18[] memory indexPricesX18;

        (
            SD59x18 marginBalanceUsdX18,
            UD60x18 initialMarginUsdX18,
            UD60x18 maintenanceMarginUsdX18,
            SD59x18 availableBalance
        ) = perpsEngine.getAccountMarginBreakdown({
            accountId: perpsAccountId,
            activeMarketsIds: activeMarketsIds,
            indexPricesX18: indexPricesX18
        });

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
