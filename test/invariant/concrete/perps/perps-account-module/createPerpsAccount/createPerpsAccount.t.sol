// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract CreatePerpsAccount_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.naruto });
    }

    function test_RevertWhen_PerpsAccountTokenNotSet() external {
        // how to make this DRY?
        bytes32 slot = bytes32(uint256(keccak256(abi.encode("fi.zaros.markets.PerpsConfiguration"))) + uint256(7));
        vm.store(address(perpsEngine), slot, bytes32(uint256(0)));

        vm.expectRevert();
        perpsEngine.createPerpsAccount();
    }

    modifier whenPerpsAccountTokenIsSet() {
        _;
    }

    function test_NoPreviousPerpsAccount() external whenPerpsAccountTokenIsSet {
        uint256 expectedAccountId = 1;

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);

        uint256 accountId = perpsEngine.createPerpsAccount();

        assertEq(accountId, expectedAccountId, "createPerpsAccount");
    }

    function test_MultiplePerpsAccounts() external whenPerpsAccountTokenIsSet {
        uint256 expectedAccountId = 2;
        perpsEngine.createPerpsAccount();

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);
        uint256 accountId = perpsEngine.createPerpsAccount();

        assertEq(accountId, expectedAccountId, "createPerpsAccount");
    }
}
