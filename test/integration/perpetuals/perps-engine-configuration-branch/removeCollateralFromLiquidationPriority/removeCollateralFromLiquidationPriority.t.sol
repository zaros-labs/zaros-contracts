// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { PerpsEngineConfigurationBranch } from "@zaros/perpetuals/branches/PerpsEngineConfigurationBranch.sol";

contract RemoveCollateralFromLiquidationPriority_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_RevertGiven_CollateralAddressIsZero() external {
        changePrank({ msgSender: users.owner.account });

        address collateral = address(0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "collateralType") });

        perpsEngine.removeCollateralFromLiquidationPriority(collateral);
    }

    modifier givenCollateralAddressIsNotZero() {
        _;
    }

    function test_RevertWhen_CollateralHasAlreadyBeenRemoved() external givenCollateralAddressIsNotZero {
        changePrank({ msgSender: users.owner.account });

        address collateral = address(usdc);

        perpsEngine.removeCollateralFromLiquidationPriority(collateral);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MarginCollateralTypeNotInPriority.selector, collateral)
        });

        perpsEngine.removeCollateralFromLiquidationPriority(collateral);
    }

    function test_WhenCollateralHasNotYetRemoved() external givenCollateralAddressIsNotZero {
        changePrank({ msgSender: users.owner.account });

        address collateral = address(usdc);

        // it should emit {LogRemoveCollateralFromLiquidationPriority} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit PerpsEngineConfigurationBranch.LogRemoveCollateralFromLiquidationPriority(
            users.owner.account, collateral
        );

        // it should remove
        perpsEngine.removeCollateralFromLiquidationPriority(collateral);
    }
}
