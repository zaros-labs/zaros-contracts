// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { RootProxy } from "@zaros/tree-proxy/RootProxy.sol";
import { getBranchUpgrades } from "script/helpers/TreeProxyHelpers.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { PerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";

contract TestContract {
    function testFunction() public pure returns (string memory) {
        return "Test";
    }
}

abstract contract PerpsEngineWithNewTestFunction is IPerpsEngine, TestContract { }

contract NewOrderBranch is OrderBranch {
    function getName(uint128 marketId) external pure returns (string memory) {
        marketId++;
        return "Test";
    }
}

abstract contract PerpsEngineWithNewOrderBranch is NewOrderBranch { }

contract Upgrade_Integration_Test is Base_Integration_Shared_Test {
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

        // it should return the new branch functions
        assertEq(PerpsEngineWithNewTestFunction(address(perpsEngine)).testFunction(), "Test");
    }

    function test_GivenReplaceABranchFunction() external {
        changePrank({ msgSender: users.owner });

        address[] memory branches = new address[](1);
        address newOrderBranch = address(new NewOrderBranch());
        branches[0] = newOrderBranch;

        bytes4[][] memory branchesSelectors = new bytes4[][](1);
        bytes4[] memory newOrderBranchSelectors = new bytes4[](1);
        newOrderBranchSelectors[0] = NewOrderBranch.getName.selector;
        branchesSelectors[0] = newOrderBranchSelectors;

        RootProxy.BranchUpgrade[] memory branchUpgrades =
            getBranchUpgrades(branches, branchesSelectors, RootProxy.BranchUpgradeAction.Replace);

        perpsEngine.upgrade(branchUpgrades, new address[](0), new bytes[](0));

        uint128 tradingAcount = 1;

        // it should return the replaced branch functions
        assertEq(PerpsEngineWithNewOrderBranch(address(perpsEngine)).getName(tradingAcount), "Test");
    }

    function test_GivenRemoveABranchFunction() external {
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
        assertEq(PerpsEngineWithNewTestFunction(address(perpsEngine)).testFunction(), "Test");

        RootProxy.BranchUpgrade[] memory newBranchUpgrades =
            getBranchUpgrades(branches, branchesSelectors, RootProxy.BranchUpgradeAction.Remove);

        perpsEngine.upgrade(newBranchUpgrades, new address[](0), new bytes[](0));

        // it should not return the removed branch functions
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.UnsupportedFunction.selector, TestContract.testFunction.selector)
        });
        PerpsEngineWithNewTestFunction(address(perpsEngine)).testFunction();
    }
}
