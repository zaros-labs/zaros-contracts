// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract isLiquidatable_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function testFuzz_WhenRequiredMaintenanceMarginUsdIsGreaterThanTheMarginBalanceUsd(
        uint256 requiredMaintenanceMarginUsd,
        int256 marginBalanceUsd
    )
        external
    {
        requiredMaintenanceMarginUsd =
            bound({ x: requiredMaintenanceMarginUsd, min: 1, max: MAX_MARGIN_REQUIREMENTS });

        vm.assume(int256(requiredMaintenanceMarginUsd) > marginBalanceUsd);

        UD60x18 requiredMaintenanceMarginUsdX18 = ud60x18(requiredMaintenanceMarginUsd);
        SD59x18 marginBalanceUsdX18 = sd59x18(marginBalanceUsd);

        bool isLiquidatable = perpsEngine.exposed_isLiquidatable(requiredMaintenanceMarginUsdX18, marginBalanceUsdX18);

        // it should return true
        assertEq(isLiquidatable, true, "isLiquidatable should return true");
    }

    function testFuzz_WhenRequiredMaintenanceMarginUsdIsLessThanOrEqualTheMarginBalanceUsd(
        uint256 requiredMaintenanceMarginUsd,
        int256 marginBalanceUsd
    )
        external
    {
        requiredMaintenanceMarginUsd =
            bound({ x: requiredMaintenanceMarginUsd, min: 1, max: MAX_MARGIN_REQUIREMENTS });

        vm.assume(int256(requiredMaintenanceMarginUsd) <= marginBalanceUsd);

        UD60x18 requiredMaintenanceMarginUsdX18 = ud60x18(requiredMaintenanceMarginUsd);
        SD59x18 marginBalanceUsdX18 = sd59x18(marginBalanceUsd);

        bool isLiquidatable = perpsEngine.exposed_isLiquidatable(requiredMaintenanceMarginUsdX18, marginBalanceUsdX18);

        // it should return false
        assertEq(isLiquidatable, false, "isLiquidatable should return false");
    }
}
