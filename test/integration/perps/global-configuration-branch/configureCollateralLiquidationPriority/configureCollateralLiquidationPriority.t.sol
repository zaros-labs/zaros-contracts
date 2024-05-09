// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { IGlobalConfigurationBranch } from "@zaros/perpetuals/interfaces/IGlobalConfigurationBranch.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";

contract ConfigureCollateralLiquidationPriority_Integration_Test is Base_Integration_Shared_Test{
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_RevertGiven_AddressArrayIsEmpty() external {
        changePrank({ msgSender: users.owner });

        address[] memory emptyArray;

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "collateralTypes")
        });

        perpsEngine.configureCollateralLiquidationPriority(emptyArray);
    }

    function test_GivenAddressArrayIsNotEmpty(address[] memory collateralTypes) external {
        vm.assume(collateralTypes.length > 0);

        changePrank({ msgSender: users.owner });

        // it should emit {LogConfigureCollateralLiquidationPriority} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit IGlobalConfigurationBranch.LogConfigureCollateralLiquidationPriority(users.owner, collateralTypes);

        // it should add
        perpsEngine.configureCollateralLiquidationPriority(collateralTypes);

    }
}
