// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract getAccountMarginBreakdown_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function testFuzz_GetAccountMarginOneCollateral(
        uint256 initialMarginValueUsd,
        uint256 initialMarketId,
        uint256 quantityFuzzMarginProfile
    )
        external
    {
        FuzzMarginProfile[] memory fuzzMarginProfiles =
            getFuzzMarginProfiles(quantityFuzzMarginProfile, initialMarketId, 0, initialMarginValueUsd);

        for (uint256 i = 0; i < fuzzMarginProfiles.length; i++) {
            FuzzMarginProfile memory marginProfile = fuzzMarginProfiles[i];

            initialMarginValueUsd = bound({ x: marginProfile.marginValueUsd, min: 1, max: USDZ_DEPOSIT_CAP });
            deal({ token: address(usdToken), to: users.naruto, give: marginProfile.marginValueUsd });

            uint256 expectedMarginBalance = getPrice(mockPriceAdapters.mockUsdcUsdPriceAdapter).mul(
                ud60x18(marginProfile.marginValueUsd)
            ).intoUint256();
            uint256 expectedAvailableBalance = expectedMarginBalance;
            uint256 expectedInitialMargin = 0;
            uint256 expectedMaintenanceMargin = 0;
            uint128 perpsAccountId = createAccountAndDeposit(marginProfile.marginValueUsd, address(usdToken));

            (
                SD59x18 marginBalanceUsdX18,
                UD60x18 initialMarginUsdX18,
                UD60x18 maintenanceMarginUsdX18,
                SD59x18 availableBalance
            ) = perpsEngine.getAccountMarginBreakdown({ accountId: perpsAccountId });

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

    function testFuzz_GetAccountMarginMultipleCollateral(
        uint256 initialMarginValueUsd,
        uint256 initialMarketId,
        uint256 quantityFuzzMarginProfile
    )
        external
    {
        FuzzMarginProfile[] memory fuzzMarginProfiles =
            getFuzzMarginProfiles(quantityFuzzMarginProfile, initialMarketId, 0, initialMarginValueUsd);

        for (uint256 i = 0; i < fuzzMarginProfiles.length; i++) {
            FuzzMarginProfile memory marginProfile = fuzzMarginProfiles[i];

            initialMarginValueUsd = bound({ x: marginProfile.marginValueUsd, min: 1, max: WSTETH_DEPOSIT_CAP });
            deal({ token: address(usdToken), to: users.naruto, give: marginProfile.marginValueUsd });
            deal({ token: address(mockWstEth), to: users.naruto, give: marginProfile.marginValueUsd });

            uint256 expectedMarginBalance = getPrice(mockPriceAdapters.mockUsdcUsdPriceAdapter).mul(
                ud60x18(marginProfile.marginValueUsd)
            ).add(
                getPrice(mockPriceAdapters.mockWstEthUsdPriceAdapter).mul(ud60x18(marginProfile.marginValueUsd)).mul(
                    ud60x18(WSTETH_LOAN_TO_VALUE)
                )
            ).intoUint256();
            uint256 expectedAvailableBalance = expectedMarginBalance;
            uint256 expectedInitialMargin = 0;
            uint256 expectedMaintenanceMargin = 0;
            uint128 perpsAccountId = createAccountAndDeposit(marginProfile.marginValueUsd, address(usdToken));
            perpsEngine.depositMargin(perpsAccountId, address(mockWstEth), marginProfile.marginValueUsd);

            (
                SD59x18 marginBalanceUsdX18,
                UD60x18 initialMarginUsdX18,
                UD60x18 maintenanceMarginUsdX18,
                SD59x18 availableBalance
            ) = perpsEngine.getAccountMarginBreakdown({ accountId: perpsAccountId });

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
}
