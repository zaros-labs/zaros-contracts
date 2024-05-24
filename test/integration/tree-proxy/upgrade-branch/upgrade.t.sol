// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { UpgradeBranch } from "@zaros/tree-proxy/branches/UpgradeBranch.sol";
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import {
    deployBranches,
    getBranchesSelectors,
    getBranchUpgrades,
    getInitializables,
    getInitializePayloads
} from "script/helpers/TreeProxyHelpers.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";

contract TestContract {
    function testFunction() public pure returns (string memory) {
        return "Test";
    }
}

abstract contract PerpsEngineWithNewTestFunction is IPerpsEngine, TestContract{}

contract Upgrade_Integration_Test is Base_Integration_Shared_Test{
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_GivenAddANewBranch() external {
        changePrank({ msgSender: users.owner });

        address[] memory branches = new address[](1);
        address testContract = address(new TestContract());
        branches[0] = testContract;

        bytes4[][] memory branchesSelectors = new bytes4[][](1);
        bytes4[] memory testContractSelectors = new bytes4[](1);
        testContractSelectors[0] = TestContract.testFunction.selector;
        branchesSelectors[0] = testContractSelectors;

        RootProxy.BranchUpgrade[] memory branchUpgrades =
            getBranchUpgrades(branches, branchesSelectors, RootProxy.BranchUpgradeAction.Add);

        perpsEngine.upgrade(branchUpgrades, new address[](0), new bytes[](0));

        // it should return the new branch
        assertEq(PerpsEngineWithNewTestFunction(address(perpsEngine)).testFunction(), "Test");
    }

    function test_GivenReplaceABranch() external {
        // it should return the replaced branch
    }

    function test_GivenRemoveABranch() external {
        // it should not return the removed branch
    }
}
