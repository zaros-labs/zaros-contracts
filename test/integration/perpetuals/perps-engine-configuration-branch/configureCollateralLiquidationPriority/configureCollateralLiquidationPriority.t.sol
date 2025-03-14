// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { PerpsEngineConfigurationBranch } from "@zaros/perpetuals/branches/PerpsEngineConfigurationBranch.sol";

contract ConfigureCollateralLiquidationPriority_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_RevertGiven_AddressArrayIsEmpty() external {
        changePrank({ msgSender: users.owner.account });

        address[] memory emptyArray;

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "collateralTypes") });

        perpsEngine.configureCollateralLiquidationPriority(emptyArray);
    }

    function test_GivenAddressArrayIsNotEmpty() external {
        address collateralType1 = address(123);
        address collateralType2 = address(456);
        address[] memory collateralTypes = new address[](2);

        collateralTypes[0] = collateralType1;
        collateralTypes[1] = collateralType2;

        changePrank({ msgSender: users.owner.account });

        // it should emit {LogConfigureCollateralLiquidationPriority} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit PerpsEngineConfigurationBranch.LogConfigureCollateralLiquidationPriority(
            users.owner.account, collateralTypes
        );

        // it should add
        perpsEngine.configureCollateralLiquidationPriority(collateralTypes);
    }
}
