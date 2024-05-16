// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { LiquidationKeeper } from "@zaros/external/chainlink/keepers/liquidation/LiquidationKeeper.sol";
import { AutomationHelpers } from "script/helpers/AutomationHelpers.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract LiquidationKeeper_SetConfig_Integration_Test is Base_Integration_Shared_Test {
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

    modifier givenCallSetConfigFunction() {
        _;
    }

    function test_RevertWhen_IAmNotTheOwner() external givenInitializeContract givenCallSetConfigFunction {
        changePrank({ msgSender: users.naruto });

        address liquidationKeeper = AutomationHelpers.deployLiquidationKeeper(
            users.owner, address(perpsEngine), users.marginCollateralRecipient, users.settlementFeeRecipient
        );

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.naruto)
        });

        LiquidationKeeper(liquidationKeeper).setConfig(
            address(perpsEngine), users.marginCollateralRecipient, users.settlementFeeRecipient
        );
    }

    modifier whenIAmTheOwner() {
        _;
    }

    function test_WhenIAmTheOwner() external givenInitializeContract givenCallSetConfigFunction whenIAmTheOwner {
        changePrank({ msgSender: users.owner });

        address liquidationKeeper = AutomationHelpers.deployLiquidationKeeper(
            users.owner, address(perpsEngine), users.marginCollateralRecipient, users.settlementFeeRecipient
        );

        address newMarginCollateralRecipient = address(0x123);
        address newSettlementFeeRecipient = address(0x456);

        LiquidationKeeper(liquidationKeeper).setConfig(
            address(perpsEngine), newMarginCollateralRecipient, newSettlementFeeRecipient
        );

        // it should update config
        (
            address keeperOwner,
            address perpsEngineOfLiquidationKeeper,
            address marginCollateralRecipient,
            address liquidationFeeRecipient
        ) = LiquidationKeeper(liquidationKeeper).getConfig();

        assertEq(keeperOwner, users.owner, "owner is not correct");

        assertEq(perpsEngineOfLiquidationKeeper, address(perpsEngine), "owner is not correct");

        assertEq(
            marginCollateralRecipient, newMarginCollateralRecipient, "margin collateral recipient is not correct"
        );
        assertEq(newSettlementFeeRecipient, liquidationFeeRecipient, "liquidation fee recipient is not correct");
    }

    function test_RevertWhen_PerpsEngineIsZero()
        external
        givenInitializeContract
        givenCallSetConfigFunction
        whenIAmTheOwner
    {
        changePrank({ msgSender: users.owner });

        address liquidationKeeper = AutomationHelpers.deployLiquidationKeeper(
            users.owner, address(perpsEngine), users.marginCollateralRecipient, users.settlementFeeRecipient
        );

        address perpsEngine = address(0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "perpsEngine") });

        LiquidationKeeper(liquidationKeeper).setConfig(
            perpsEngine, users.marginCollateralRecipient, users.settlementFeeRecipient
        );
    }

    function test_RevertWhen_MarginCollateralRecipientIsZero()
        external
        givenInitializeContract
        givenCallSetConfigFunction
        whenIAmTheOwner
    {
        changePrank({ msgSender: users.owner });

        address liquidationKeeper = AutomationHelpers.deployLiquidationKeeper(
            users.owner, address(perpsEngine), users.marginCollateralRecipient, users.settlementFeeRecipient
        );

        address newMarginCollateralRecipient = address(0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "marginCollateralRecipient") });

        LiquidationKeeper(liquidationKeeper).setConfig(
            address(perpsEngine), newMarginCollateralRecipient, users.settlementFeeRecipient
        );
    }

    function test_RevertWhen_LiquidationFeeRecipientIsZero()
        external
        givenInitializeContract
        givenCallSetConfigFunction
        whenIAmTheOwner
    {
        changePrank({ msgSender: users.owner });

        address liquidationKeeper = AutomationHelpers.deployLiquidationKeeper(
            users.owner, address(perpsEngine), users.marginCollateralRecipient, users.settlementFeeRecipient
        );

        address newSettlementFeeRecipient = address(0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "liquidationFeeRecipient") });

        LiquidationKeeper(liquidationKeeper).setConfig(
            address(perpsEngine), users.marginCollateralRecipient, newSettlementFeeRecipient
        );
    }
}
