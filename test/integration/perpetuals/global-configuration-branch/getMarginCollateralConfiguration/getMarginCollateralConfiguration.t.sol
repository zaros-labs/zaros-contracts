// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { MarginCollateralConfiguration } from "@zaros/perpetuals/leaves/MarginCollateralConfiguration.sol";

// OpenZeppelin Upgradeable dependencies
import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

contract GetMarginCollateralConfiguration_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_GivenAValidCollateralAddress() external {
        // it should return the margin collateral configuration
        MarginCollateralConfiguration.Data memory collateralConfiguration =
            perpsEngine.getMarginCollateralConfiguration(address(wstEthMarginCollateral));

        assertEq(collateralConfiguration.decimals, ERC20(wstEthMarginCollateral).decimals());
    }
}
