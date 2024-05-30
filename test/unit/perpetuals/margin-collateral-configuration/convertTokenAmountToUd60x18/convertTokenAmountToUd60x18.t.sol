// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { MarginCollateralConfiguration } from "@zaros/perpetuals/leaves/MarginCollateralConfiguration.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract MarginCollateralConfiguration_ConvertTokenAmountToUd60x18_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_GivenMarginCollateralDecimalsIsEqualToSystemDecimals(uint256 amount) external {
        UD60x18 expectedValue = ud60x18(amount);

        UD60x18 value = perpsEngine.exposed_convertTokenAmountToUd60x18(address(usdToken), amount);

        // it should return the amount to UD60x18
        assertEq(value.intoUint256(), expectedValue.intoUint256(), "value is not correct");
    }

    function testFuzz_GivenMarginCiollateralDecimalsIsNotEqualToSystemDecimals(
        uint128 newDepositCap,
        uint120 newLoanToValue,
        uint8 newDecimals,
        address newPriceFeed
    )
        external
    {
        uint256 amount = 100;

        vm.assume(newDecimals < Constants.SYSTEM_DECIMALS && newDecimals > 0);

        perpsEngine.exposed_configure(address(usdToken), newDepositCap, newLoanToValue, newDecimals, newPriceFeed);

        UD60x18 expectedValue = ud60x18(amount * 10 ** (Constants.SYSTEM_DECIMALS - newDecimals));

        UD60x18 value = perpsEngine.exposed_convertTokenAmountToUd60x18(address(usdToken), amount);

        // it should return the amount raised to the decimals of the system minus the decimals of the margin
        // collateral to UD60x18
        assertEq(value.intoUint256(), expectedValue.intoUint256(), "value is not correct");
    }
}
