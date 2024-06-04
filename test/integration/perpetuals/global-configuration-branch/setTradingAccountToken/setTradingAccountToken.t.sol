// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";

// Open Zeppelin dependencies
import { Ownable } from "@openzeppelin/access/Ownable.sol";

contract SetTradingAccountToken_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheOwner(address tradingAccountToken) external {
        changePrank({ msgSender: users.naruto });

        vm.assume(tradingAccountToken != address(0));

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users.naruto)
        });

        perpsEngine.setTradingAccountToken(tradingAccountToken);
    }

    modifier givenTheSenderIsTheOwner() {
        _;
    }

    function test_RevertWhen_TheTradingAccountTokenIsZero() external givenTheSenderIsTheOwner {
        changePrank({ msgSender: users.owner });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.TradingAccountTokenNotDefined.selector) });

        perpsEngine.setTradingAccountToken(address(0));
    }

    function test_WhenTheTradingAccountTokenIsNotAZero(address tradingAccountToken)
        external
        givenTheSenderIsTheOwner
    {
        changePrank({ msgSender: users.owner });

        vm.assume(tradingAccountToken != address(0));

        // it should emit a {LogSetTradingAccountToken} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit GlobalConfigurationBranch.LogSetTradingAccountToken(users.owner, tradingAccountToken);

        perpsEngine.setTradingAccountToken(tradingAccountToken);
    }
}
