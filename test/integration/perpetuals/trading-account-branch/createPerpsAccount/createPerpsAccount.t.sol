// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";

contract CreateTradingAccount_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function test_RevertGiven_TheTradingAccountTokenIsNotSet() external {
        bytes32 slot = bytes32(uint256(GLOBAL_CONFIGURATION_SLOT) + uint256(3));
        vm.store(address(perpsEngine), slot, bytes32(uint256(0)));

        // it should revert
        vm.expectRevert();
        perpsEngine.createTradingAccount();
    }

    modifier givenTheTradingAccountTokenIsSet() {
        _;
    }

    function test_GivenTheCallerHasNoPreviousTradingAccount() external givenTheTradingAccountTokenIsSet {
        uint128 expectedAccountId = 1;

        // it should emit {LogCreateTradingAccount}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit TradingAccountBranch.LogCreateTradingAccount(expectedAccountId, users.naruto);

        uint128 tradingAccountId = perpsEngine.createTradingAccount();

        // it should return a valid tradingAccountId
        assertEq(tradingAccountId, expectedAccountId, "createTradingAccount");
    }

    function test_GivenTheCallerHasAPreviouslyCreatedTradingAccount() external givenTheTradingAccountTokenIsSet {
        uint128 expectedAccountId = 2;
        perpsEngine.createTradingAccount();

        // it should emit {LogCreateTradingAccount}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit TradingAccountBranch.LogCreateTradingAccount(expectedAccountId, users.naruto);
        uint128 tradingAccountId = perpsEngine.createTradingAccount();

        // it should return a valid tradingAccountId
        assertEq(tradingAccountId, expectedAccountId, "createTradingAccount");
    }
}
