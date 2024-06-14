// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";

contract RemoveCollateralFromLiquidationPriority_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_RevertGiven_CollateralAddressIsZero() external {
        changePrank({ msgSender: users.owner });

        address collateral = address(0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "collateralType") });

        perpsEngine.removeCollateralFromLiquidationPriority(collateral);
    }

    modifier givenCollateralAddressIsNotZero() {
        _;
    }

    function test_RevertWhen_CollateralHasAlreadyBeenRemoved() external givenCollateralAddressIsNotZero {
        changePrank({ msgSender: users.owner });

        address collateral = address(usdcMarginCollateral);

        perpsEngine.removeCollateralFromLiquidationPriority(collateral);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MarginCollateralTypeNotInPriority.selector, collateral)
        });

        perpsEngine.removeCollateralFromLiquidationPriority(collateral);
    }

    function test_WhenCollateralHasNotYetRemoved() external givenCollateralAddressIsNotZero {
        changePrank({ msgSender: users.owner });

        address collateral = address(usdcMarginCollateral);

        // it should emit {LogRemoveCollateralFromLiquidationPriority} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit GlobalConfigurationBranch.LogRemoveCollateralFromLiquidationPriority(users.owner, collateral);

        // it should remove
        perpsEngine.removeCollateralFromLiquidationPriority(collateral);
    }
}
