// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

contract CreatePerpsAccount_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function test_RevertGiven_ThePerpsAccountTokenIsNotSet() external {
        bytes32 slot = bytes32(uint256(GLOBAL_CONFIGURATION_SLOT) + uint256(3));
        vm.store(address(perpsEngine), slot, bytes32(uint256(0)));

        // it should revert
        vm.expectRevert();
        perpsEngine.createPerpsAccount();
    }

    modifier givenThePerpsAccountTokenIsSet() {
        _;
    }

    function test_GivenTheCallerHasNoPreviousPerpsAccount() external givenThePerpsAccountTokenIsSet {
        uint128 expectedAccountId = 1;

        // it should emit {LogCreatePerpsAccount}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);

        uint128 accountId = perpsEngine.createPerpsAccount();

        // it should return a valid accountId
        assertEq(accountId, expectedAccountId, "createPerpsAccount");
    }

    function test_GivenTheCallerHasAPreviouslyCreatedPerpsAccount() external givenThePerpsAccountTokenIsSet {
        uint128 expectedAccountId = 2;
        perpsEngine.createPerpsAccount();

        // it should emit {LogCreatePerpsAccount}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);
        uint128 accountId = perpsEngine.createPerpsAccount();

        // it should return a valid accountId
        assertEq(accountId, expectedAccountId, "createPerpsAccount");
    }
}
