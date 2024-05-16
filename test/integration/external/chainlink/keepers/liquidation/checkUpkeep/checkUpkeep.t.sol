// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { LiquidationKeeper } from "@zaros/external/chainlink/keepers/liquidation/LiquidationKeeper.sol";
import { LiquidationBranch_Integration_Test } from "test/integration/shared/LiquidationBranchIntegration.t.sol";

contract LiquidationKeeper_CheckUpkeep_Integration_Test is LiquidationBranch_Integration_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertWhen_TheCheckLowerBoundIsHigherThanTheCheckUpperBound(
        uint256 checkLowerBound,
        uint256 checkUpperBound,
        uint256 performLowerBound,
        uint256 performUpperBound
    )
        external
    {
        checkLowerBound = bound({ x: checkLowerBound, min: 1, max: 1000 });
        checkUpperBound = bound({ x: checkUpperBound, min: 0, max: checkLowerBound - 1 });
        performLowerBound = bound({ x: performLowerBound, min: 0, max: 1000 });
        performUpperBound = bound({ x: performUpperBound, min: performLowerBound + 1, max: performLowerBound + 16 });

        bytes memory checkData = abi.encode(checkLowerBound, checkUpperBound, performLowerBound, performUpperBound);

        // it should revert
        vm.expectRevert({ revertData: Errors.InvalidBounds.selector });
        LiquidationKeeper(liquidationKeeper).checkUpkeep(checkData);
    }

    modifier whenTheCheckLowerBoundIsLowerThanTheCheckUpperBound() {
        _;
    }

    function testFuzz_RevertWhen_ThePerformLowerBoundIsHigherThanThePerformUpperBound(
        uint256 checkLowerBound,
        uint256 checkUpperBound,
        uint256 performLowerBound,
        uint256 performUpperBound
    )
        external
        whenTheCheckLowerBoundIsLowerThanTheCheckUpperBound
    {
        checkLowerBound = bound({ x: checkLowerBound, min: 0, max: 1000 });
        checkUpperBound = bound({ x: checkUpperBound, min: checkLowerBound + 1, max: checkLowerBound + 101 });
        performLowerBound = bound({ x: performLowerBound, min: 1, max: 1000 });
        performUpperBound = bound({ x: performUpperBound, min: 0, max: performLowerBound - 1 });

        bytes memory checkData = abi.encode(checkLowerBound, checkUpperBound, performLowerBound, performUpperBound);

        // it should revert
        vm.expectRevert({ revertData: Errors.InvalidBounds.selector });
        LiquidationKeeper(liquidationKeeper).checkUpkeep(checkData);
    }

    modifier whenThePerformLowerBoundIsLowerThanThePerformUpperBound() {
        _;
    }

    function testFuzz_GivenThereAreNoLiquidatableAccountsIds(
        uint256 checkLowerBound,
        uint256 checkUpperBound,
        uint256 performLowerBound,
        uint256 performUpperBound
    )
        external
        whenTheCheckLowerBoundIsLowerThanTheCheckUpperBound
        whenThePerformLowerBoundIsLowerThanThePerformUpperBound
    {
        checkLowerBound = bound({ x: checkLowerBound, min: 0, max: 1000 });
        checkUpperBound = bound({ x: checkUpperBound, min: checkLowerBound + 1, max: checkLowerBound + 101 });
        performLowerBound = bound({ x: performLowerBound, min: 1, max: 1000 });
        performUpperBound = bound({ x: performUpperBound, min: 0, max: performLowerBound - 1 });

        bytes memory checkData = abi.encode(checkLowerBound, checkUpperBound, performLowerBound, performUpperBound);

        // it should revert
        vm.expectRevert({ revertData: Errors.InvalidBounds.selector });
        LiquidationKeeper(liquidationKeeper).checkUpkeep(checkData);

        // it should return upkeepNeeded == false
        // it should return an empty byte array
    }

    function test_GivenThereAreLiquidatableAccounts()
        external
        whenTheCheckLowerBoundIsLowerThanTheCheckUpperBound
        whenThePerformLowerBoundIsLowerThanThePerformUpperBound
    {
        // it should return upkeepNeeded == true
        // it should return the abi encoded liquidatable accounts ids
    }
}
