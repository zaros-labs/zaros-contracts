// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract CancelAllOffchainOrders_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_RevertGiven_TheTradingAccountDoesNotExist() external {
        // it should revert
    }

    modifier givenTheTradingAccountExists() {
        _;
    }

    function test_RevertGiven_TheSenderIsNotTheOwner() external givenTheTradingAccountExists {
        // it should revert
    }

    function test_GivenTheSenderIsTheOwner() external givenTheTradingAccountExists {
        // it should increase the trading account nonce
        // it should emit {LogCancelAllOffchainOrders}
    }
}
