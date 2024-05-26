// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { TradingAccountBranch } from "@zaros/perpetuals/branches/TradingAccountBranch.sol";
import { Base_Test } from "test/Base.t.sol";

contract CreateTradingAccountAndMulticall_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_RevertWhen_TheDataArrayProvidesARevertingCall() external {
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(TradingAccountBranch.depositMargin.selector, address(usdToken), uint256(0));

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });
        perpsEngine.createTradingAccountAndMulticall(data);
    }

    modifier whenTheDataArrayDoesNotProvideARevertingCall() {
        _;
    }

    function test_WhenTheDataArrayIsNull() external whenTheDataArrayDoesNotProvideARevertingCall {
        bytes[] memory data = new bytes[](0);
        uint128 expectedAccountId = 1;
        uint256 expectedResultsLength = 0;

        // it should emit {LogCreateTradingAccount}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit TradingAccountBranch.LogCreateTradingAccount(expectedAccountId, users.naruto);

        bytes[] memory results = perpsEngine.createTradingAccountAndMulticall(data);
        // it should return a null results array
        assertEq(results.length, expectedResultsLength, "createTradingAccountAndMulticall");
    }

    function test_WhenTheDataArrayIsNotNull() external whenTheDataArrayDoesNotProvideARevertingCall {
        bytes[] memory data = new bytes[](1);
        uint128 expectedAccountId = 1;
        data[0] = abi.encodeWithSelector(TradingAccountBranch.getTradingAccountToken.selector);

        // it should emit {LogCreateTradingAccount}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit TradingAccountBranch.LogCreateTradingAccount(expectedAccountId, users.naruto);

        bytes[] memory results = perpsEngine.createTradingAccountAndMulticall(data);
        address tradingAccountTokenReturned = abi.decode(results[0], (address));

        // it should return a valid results array
        assertEq(tradingAccountTokenReturned, address(tradingAccountToken), "createTradingAccountAndMulticall");
    }

    function testFuzz_CreateTradingAccountAndDepositMargin(uint256 amountToDeposit)
        external
        whenTheDataArrayDoesNotProvideARevertingCall
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        bytes[] memory data = new bytes[](1);
        data[0] =
            abi.encodeWithSelector(TradingAccountBranch.depositMargin.selector, address(usdToken), amountToDeposit);
        uint128 expectedAccountId = 1;

        // it should transfer the amount from the sender to the trading account
        expectCallToTransferFrom(usdToken, users.naruto, address(perpsEngine), amountToDeposit);
        bytes[] memory results = perpsEngine.createTradingAccountAndMulticall(data);

        uint256 newMarginCollateralBalance =
            perpsEngine.getAccountMarginCollateralBalance(expectedAccountId, address(usdToken)).intoUint256();

        // it should increase the amount of margin collateral
        assertEq(results.length, 1, "createTradingAccountAndMulticall: results");
        assertEq(newMarginCollateralBalance, amountToDeposit, "createTradingAccountAndMulticall: account margin");
    }
}
