// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract CreatePerpsAccount_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.naruto });
    }

    function test_CreatePerpsAccount() external {
        uint256 expectedAccountId = 1;

        vm.expectEmit({ emitter: address(perpsExchange) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);

        uint256 accountId = perpsExchange.createPerpsAccount();

        assertEq(accountId, expectedAccountId, "createPerpsAccount");
    }

    function test_CreatePerpsAccount_NotFirstAccount() external {
        uint256 expectedAccountId = 2;
        perpsExchange.createPerpsAccount();

        vm.expectEmit({ emitter: address(perpsExchange) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);
        uint256 accountId = perpsExchange.createPerpsAccount();

        assertEq(accountId, expectedAccountId, "createPerpsAccount");
    }
}
