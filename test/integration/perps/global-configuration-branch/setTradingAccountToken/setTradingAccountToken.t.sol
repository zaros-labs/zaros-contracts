// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { IGlobalConfigurationBranch } from "@zaros/perpetuals/interfaces/IGlobalConfigurationBranch.sol";

contract SetTradingAccountToken_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function test_RevertGiven_TheTradingAccountTokenIsZero() external {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.TradingAccountTokenNotDefined.selector) });

        perpsEngine.setTradingAccountToken(address(0));
    }

    function test_GivenTheTradingAccountTokenIsNotAZero(address tradingAccountToken) external {
        vm.assume(tradingAccountToken != address(0));

        // it should emit a {LogSetTradingAccountToken} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit IGlobalConfigurationBranch.LogSetTradingAccountToken(users.naruto, tradingAccountToken);

        perpsEngine.setTradingAccountToken(tradingAccountToken);
    }
}
