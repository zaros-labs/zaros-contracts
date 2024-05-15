// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { LiquidationKeeper } from "@zaros/external/chainlink/keepers/liquidation/LiquidationKeeper.sol";
import { AutomationHelpers } from "script/helpers/AutomationHelpers.sol";

contract LiquidationKeeperGetConfig_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    modifier givenInitializeContract() {
        _;
    }

    function test_WhenCallGetConfigFunction() external givenInitializeContract {
        address liquidationKeeper = AutomationHelpers.deployLiquidationKeeper(
            address(perpsEngine), users.marginCollateralRecipient, users.settlementFeeRecipient
        );

        (address keeperOwner, address marginCollateralRecipient, address liquidationFeeRecipient) =
            LiquidationKeeper(liquidationKeeper).getConfig();

        // it should return owner
        assertEq(keeperOwner, address(perpsEngine), "owner is not correct");

        // it should return margin collateral fee recipient
        assertEq(
            users.marginCollateralRecipient, marginCollateralRecipient, "margin collateral recipient is not correct"
        );

        // it should return liquidation fee recipient
        assertEq(users.settlementFeeRecipient, liquidationFeeRecipient, "liquidation fee recipient is not correct");
    }
}
