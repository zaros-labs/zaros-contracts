// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { IGlobalConfigurationBranch } from "@zaros/perpetuals/interfaces/IGlobalConfigurationBranch.sol";

contract ConfigureLiquidators_Integration_Teste is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function test_RevertGiven_ThereAreNoLiquidators() external {
        address[] memory liquidators = new address[](0);
        bool[] memory enable = new bool[](0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "liquidators") });

        changePrank({ msgSender: users.owner });

        perpsEngine.configureLiquidators(liquidators, enable);

        changePrank({ msgSender: users.naruto });
    }

    modifier givenThereAreLiquidators() {
        _;
    }

    function test_RevertGiven_NumberOfLiquidatorsAndArrayOfEnableIsDifferent(address randomLiquidator)
        external
        givenThereAreLiquidators
    {
        address[] memory liquidators = new address[](1);
        bool[] memory enable = new bool[](0);

        liquidators[0] = randomLiquidator;

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.ArrayLengthMismatch.selector, liquidators.length, enable.length)
        });

        changePrank({ msgSender: users.owner });

        perpsEngine.configureLiquidators(liquidators, enable);

        changePrank({ msgSender: users.naruto });
    }

    function test_GivenNumberOfLiquidatorsAndArrayOfEnableIsEqual(address randomLiquidator)
        external
        givenThereAreLiquidators
    {
        address[] memory liquidators = new address[](1);
        bool[] memory enable = new bool[](1);

        liquidators[0] = randomLiquidator;

        // it should emit a {LogConfigureLiquidators} event
        vm.expectEmit();
        emit IGlobalConfigurationBranch.LogConfigureLiquidators(users.owner, liquidators, enable);

        changePrank({ msgSender: users.owner });

        perpsEngine.configureLiquidators(liquidators, enable);

        changePrank({ msgSender: users.naruto });
    }
}
