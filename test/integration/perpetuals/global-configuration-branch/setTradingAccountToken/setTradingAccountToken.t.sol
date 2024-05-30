// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";

contract SetTradingAccountToken_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_RevertGiven_TheTradingAccountTokenIsZero() external {
        changePrank({ msgSender: users.owner });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.TradingAccountTokenNotDefined.selector) });

        perpsEngine.setTradingAccountToken(address(0));
    }

    function testFuzz_GivenTheTradingAccountTokenIsNotAZero(address tradingAccountToken) external {
        changePrank({ msgSender: users.owner });

        vm.assume(tradingAccountToken != address(0));

        // it should emit a {LogSetTradingAccountToken} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit GlobalConfigurationBranch.LogSetTradingAccountToken(users.owner, tradingAccountToken);

        perpsEngine.setTradingAccountToken(tradingAccountToken);
    }
}
