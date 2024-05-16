// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { LiquidationKeeper } from "@zaros/external/chainlink/keepers/liquidation/LiquidationKeeper.sol";
import { LiquidationBranch } from "@zaros/perpetuals/branches/LiquidationBranch.sol";
import { LiquidationBranch_Integration_Test } from
    "test/integration/perpetuals/liquidation-branch/LiquidationBranchIntegration.t.sol";

contract LiquidationKeeper_CheckUpkeep_Integration_Test is LiquidationBranch_Integration_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    function test_RevertWhen_TheCheckLowerBoundIsHigherThanTheCheckUpperBound() external {
        // it should revert
    }

    modifier whenTheCheckLowerBoundIsLowerThanTheCheckUpperBound() {
        _;
    }

    modifier whenThePerformLowerBoundIsHigherThanThePerformUpperBound() {
        _;
    }

    function test_RevertWhen_ThePerformLowerBoundIsHigherThanThePerformUpperBound()
        external
        whenTheCheckLowerBoundIsLowerThanTheCheckUpperBound
        whenThePerformLowerBoundIsHigherThanThePerformUpperBound
    {
        // it should revert
    }

    modifier whenThePerformLowerBoundIsLowerThanThePerformUpperBound() {
        _;
    }

    function test_GivenThereAreNoLiquidatableAccountsIds()
        external
        whenTheCheckLowerBoundIsLowerThanTheCheckUpperBound
        whenThePerformLowerBoundIsHigherThanThePerformUpperBound
        whenThePerformLowerBoundIsLowerThanThePerformUpperBound
    {
        // it should return upkeepNeeded == false
        // it should return an empty byte array
    }

    function test_GivenThereAreLiquidatableAccounts()
        external
        whenTheCheckLowerBoundIsLowerThanTheCheckUpperBound
        whenThePerformLowerBoundIsHigherThanThePerformUpperBound
        whenThePerformLowerBoundIsLowerThanThePerformUpperBound
    {
        // it should return upkeepNeeded == true
        // it should return the abi encoded liquidatable accounts ids
    }
}
