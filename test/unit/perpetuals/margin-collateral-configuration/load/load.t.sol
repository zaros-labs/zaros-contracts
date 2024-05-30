// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { MarginCollateralConfiguration } from "@zaros/perpetuals/leaves/MarginCollateralConfiguration.sol";

contract MarginCollateralConfiguration_Load_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_WhenLoadIsCalled() external {
        MarginCollateralConfiguration.Data memory marginCollateralConfiguration =
            perpsEngine.exposed_MarginCollateral_load(address(usdToken));

        // it should return the maximum deposit cap
        assertEq(marginCollateralConfiguration.depositCap, USDZ_DEPOSIT_CAP, "invalid deposit cap");

        // it should return the loan to value
        assertEq(marginCollateralConfiguration.loanToValue, USDZ_LOAN_TO_VALUE, "invalid loan to value");

        // it should return the decimals
        assertEq(marginCollateralConfiguration.decimals, 18, "invalid decimals");

        // it should return the price feed
        assertEq(
            marginCollateralConfiguration.priceFeed,
            address(mockPriceAdapters.mockUsdcUsdPriceAdapter),
            "invalid price feed"
        );
    }
}
