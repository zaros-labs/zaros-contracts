// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { LiquidationKeeper } from "@zaros/external/chainlink/keepers/liquidation/LiquidationKeeper.sol";
import { AutomationHelpers } from "script/helpers/AutomationHelpers.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract LiquidationKeeper_SetConfig_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
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

        address liquidationKeeper =
            AutomationHelpers.deployLiquidationKeeper(users.owner, address(perpsEngine), users.settlementFeeRecipient);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.naruto)
        });

        LiquidationKeeper(liquidationKeeper).setConfig(address(perpsEngine), users.settlementFeeRecipient);
    }

    modifier whenIAmTheOwner() {
        _;
    }

    function test_WhenIAmTheOwner() external givenInitializeContract givenCallSetConfigFunction whenIAmTheOwner {
        changePrank({ msgSender: users.owner });

        address liquidationKeeper =
            AutomationHelpers.deployLiquidationKeeper(users.owner, address(perpsEngine), users.settlementFeeRecipient);

        address newSettlementFeeRecipient = address(0x456);

        LiquidationKeeper(liquidationKeeper).setConfig(address(perpsEngine), newSettlementFeeRecipient);

        // it should update config
        (address keeperOwner, address perpsEngineOfLiquidationKeeper, address liquidationFeeRecipient) =
            LiquidationKeeper(liquidationKeeper).getConfig();

        assertEq(keeperOwner, users.owner, "owner is not correct");

        assertEq(perpsEngineOfLiquidationKeeper, address(perpsEngine), "owner is not correct");

        assertEq(newSettlementFeeRecipient, liquidationFeeRecipient, "liquidation fee recipient is not correct");
    }

    function test_RevertWhen_PerpsEngineIsZero()
        external
        givenInitializeContract
        givenCallSetConfigFunction
        whenIAmTheOwner
    {
        changePrank({ msgSender: users.owner });

        address liquidationKeeper =
            AutomationHelpers.deployLiquidationKeeper(users.owner, address(perpsEngine), users.settlementFeeRecipient);

        address perpsEngine = address(0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "perpsEngine") });

        LiquidationKeeper(liquidationKeeper).setConfig(perpsEngine, users.settlementFeeRecipient);
    }

    function test_RevertWhen_LiquidationFeeRecipientIsZero()
        external
        givenInitializeContract
        givenCallSetConfigFunction
        whenIAmTheOwner
    {
        changePrank({ msgSender: users.owner });

        address liquidationKeeper =
            AutomationHelpers.deployLiquidationKeeper(users.owner, address(perpsEngine), users.settlementFeeRecipient);

        address newSettlementFeeRecipient = address(0);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "liquidationFeeRecipient") });

        LiquidationKeeper(liquidationKeeper).setConfig(address(perpsEngine), newSettlementFeeRecipient);
    }
}
