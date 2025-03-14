// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { Base_Test } from "test/Base.t.sol";

contract CancelAllOffchainOrders_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_RevertGiven_TheTradingAccountDoesNotExist() external {
        uint128 nonExistingTradingAccountId = 1;

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AccountNotFound.selector, nonExistingTradingAccountId, users.naruto.account
            )
        });
        perpsEngine.cancelAllOffchainOrders(nonExistingTradingAccountId);
    }

    modifier givenTheTradingAccountExists() {
        _;
    }

    function test_RevertGiven_TheSenderIsNotTheOwner() external givenTheTradingAccountExists {
        uint128 tradingAccountId = perpsEngine.createTradingAccount(bytes(""), false);

        changePrank({ msgSender: users.sasuke.account });
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.AccountPermissionDenied.selector, tradingAccountId, users.sasuke.account
            )
        });
        perpsEngine.cancelAllOffchainOrders(tradingAccountId);
    }

    function test_GivenTheSenderIsTheOwner() external givenTheTradingAccountExists {
        uint128 tradingAccountId = perpsEngine.createTradingAccount(bytes(""), false);
        uint128 expectedNonce = 1;

        // it should emit {LogCancelAllOffchainOrders}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit OrderBranch.LogCancelAllOffchainOrders(users.naruto.account, tradingAccountId, expectedNonce);
        perpsEngine.cancelAllOffchainOrders(tradingAccountId);

        uint128 newNonce = perpsEngine.workaround_getNonce(tradingAccountId);

        // it should increase the trading account nonce
        assertEq(expectedNonce, newNonce, "tradingAccount.nonce");
    }
}
