// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";

contract RemoveCollateralFromLiquidationPriority_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_RevertWhen_TheCollateralIsAlreadyRemovedInTheLiquidationPriority() external {
        address collateralType1 = address(123);
        address collateralType2 = address(456);
        address[] memory collateralTypes = new address[](2);

        collateralTypes[0] = collateralType1;
        collateralTypes[1] = collateralType2;

        perpsEngine.exposed_configureCollateralLiquidationPriority(collateralTypes);

        perpsEngine.exposed_removeCollateralFromLiquidationPriority(collateralType1);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MarginCollateralTypeNotInPriority.selector, collateralType1)
        });

        perpsEngine.exposed_removeCollateralFromLiquidationPriority(collateralType1);
    }

    function test_WhenTheCollateralWasNotRemovedInTheLiquidationPriority() external {
        address collateralType1 = address(123);

        address[] memory collateralTypes = new address[](1);

        collateralTypes[0] = collateralType1;

        perpsEngine.exposed_configureCollateralLiquidationPriority(collateralTypes);

        // it should remove the collateral in the liquidation priority
        perpsEngine.exposed_removeCollateralFromLiquidationPriority(collateralType1);

        perpsEngine.exposed_configureCollateralLiquidationPriority(collateralTypes);
    }
}
