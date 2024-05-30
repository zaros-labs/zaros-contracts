// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { MarginCollateralConfiguration } from "@zaros/perpetuals/leaves/MarginCollateralConfiguration.sol";

contract MarginCollateralConfiguration_Configure_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_WhenConfigureIsCalled() external {
        uint256 newDepositCap = 1000;
        uint256 newLoanToValue = 100;
        uint256 newDecimals = 8;
        address newPriceFeed = address(0x123);

        perpsEngine.exposed_configure(address(usdToken), newDepositCap, newLoanToValue, newDecimals, newPriceFeed);

        MarginCollateralConfiguration.Data memory marginCollateralConfiguration =
            perpsEngine.exposed_MarginCollateral_load(address(usdToken));

        // it should update the maximum deposit cap
        assertEq(marginCollateralConfiguration.depositCap, newDepositCap, "invalid deposit cap");

        // it should update the loan to value
        assertEq(marginCollateralConfiguration.loanToValue, newLoanToValue, "invalid loan to value");

        // it should update the decimals
        assertEq(marginCollateralConfiguration.decimals, newDecimals, "invalid decimals");

        // it should update the price feed
        assertEq(marginCollateralConfiguration.priceFeed, newPriceFeed, "invalid price feed");
    }
}
