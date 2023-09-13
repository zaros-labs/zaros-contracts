// SPDX-LICENSE-IDENTIFIER: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract CreatePerpsAccount_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        vm.startPrank({ msgSender: users.naruto });
    }

    function test_CreatePerpsAccount() public {
        uint256 expectedAccountId = 1;

        vm.expectEmit({ emitter: address(perpsManager) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);

        uint256 accountId = perpsManager.createPerpsAccount();

        assertEq(accountId, expectedAccountId, "createPerpsAccount");
    }

    function test_CreatePerpsAccount_NotFirstAccount() public {
        uint256 expectedAccountId = 2;
        perpsManager.createPerpsAccount();

        vm.expectEmit({ emitter: address(perpsManager) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);
        uint256 accountId = perpsManager.createPerpsAccount();

        assertEq(accountId, expectedAccountId, "createPerpsAccount");
    }
}
