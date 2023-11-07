// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract CreatePerpsAccount_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_RevertGiven_ThePerpsAccountTokenIsNotSet() external {
        bytes32 slot = bytes32(uint256(PERPS_CONFIGURATION_SLOT) + uint256(7));
        vm.store(address(perpsEngine), slot, bytes32(uint256(0)));

        // it should revert
        vm.expectRevert();
        perpsEngine.createPerpsAccount();
    }

    modifier givenThePerpsAccountTokenIsSet() {
        _;
    }

    function test_GivenTheCallerHasNoPreviousPerpsAccount() external givenThePerpsAccountTokenIsSet {
        uint256 expectedAccountId = 1;

        // it should emit {LogCreatePerpsAccount}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);

        uint256 accountId = perpsEngine.createPerpsAccount();

        // it should return a valid accountId
        assertEq(accountId, expectedAccountId, "createPerpsAccount");
    }

    function test_GivenTheCallerHasAPreviouslyCreatedPerpsAccount() external givenThePerpsAccountTokenIsSet {
        uint256 expectedAccountId = 2;
        perpsEngine.createPerpsAccount();

        // it should emit {LogCreatePerpsAccount}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);
        uint256 accountId = perpsEngine.createPerpsAccount();

        // it should return a valid accountId
        assertEq(accountId, expectedAccountId, "createPerpsAccount");
    }
}
