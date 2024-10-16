// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { FeeDistributionBranch } from "@zaros/market-making/branches/FeeDistributionBranch.sol";

// Openzeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

contract SendWethToFeeRecipients_Integration_Test is Base_Test {
    using EnumerableSet for EnumerableSet.UintSet;

    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: address(users.owner.account) });
        configureMarketsDebt();
    }

    function testFuzz_RevertGiven_TheSenderIsNotRegisteredEngine(uint256 marketDebtId, uint256 configuration) external {
        changePrank({ msgSender: users.naruto.account });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.Unauthorized.selector, users.naruto.account) });
        marketMakingEngine.sendWethToFeeRecipients(uint128(marketDebtId), configuration);
    }

    modifier givenTheSenderIsRegisteredEngine() {
        _;
    }

    function test_RevertWhen_TheMarketDoesNotExist() external givenTheSenderIsRegisteredEngine {
        // it should revert
    }

    modifier whenTheMarketExist() {
        _;
    }

    function test_RevertWhen_ThereIsNoAvailableFeesToWithdraw()
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
    {
        // it should revert
    }

    modifier whenThereIsAvailableFeesToWithdraw() {
        _;
    }

    function test_RevertWhen_ThereAreNoFeeRecipients()
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenThereIsAvailableFeesToWithdraw
    {
        // it should revert
    }

    function test_WhenThereAreFeeRecipients()
        external
        givenTheSenderIsRegisteredEngine
        whenTheMarketExist
        whenThereIsAvailableFeesToWithdraw
    {
        // it should transfer the fees to the fee recipients
        // it should emit {LogSendWethToFeeRecipients} event
        // it should decrement the available fees to withdraw
    }

}
