// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { IPerpsAccountModule } from "@zaros/markets/perps/interfaces/IPerpsAccountModule.sol";
import { Base_Test } from "test/Base.t.sol";

import "forge-std/console.sol";

contract CreatePerpsAccountAndMulticall_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_RevertWhen_TheDataArrayProvidesARevertingCall() external {
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(IPerpsAccountModule.depositMargin.selector, address(usdToken), uint256(0));

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "amount") });
        perpsEngine.createPerpsAccountAndMulticall(data);
    }

    modifier whenTheDataArrayDoesNotProvideARevertingCall() {
        _;
    }

    function test_WhenTheDataArrayIsNull() external whenTheDataArrayDoesNotProvideARevertingCall {
        bytes[] memory data = new bytes[](0);
        uint128 expectedAccountId = 1;
        uint256 expectedResultsLength = 0;

        // it should emit {LogCreatePerpsAccount}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);

        bytes[] memory results = perpsEngine.createPerpsAccountAndMulticall(data);
        // it should return a null results array
        assertEq(results.length, expectedResultsLength, "createPerpsAccountAndMulticall");
    }

    function test_WhenTheDataArrayIsNotNull() external whenTheDataArrayDoesNotProvideARevertingCall {
        bytes[] memory data = new bytes[](1);
        uint128 expectedAccountId = 1;
        data[0] = abi.encodeWithSelector(IPerpsAccountModule.getPerpsAccountToken.selector);

        // it should emit {LogCreatePerpsAccount}
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);

        bytes[] memory results = perpsEngine.createPerpsAccountAndMulticall(data);
        address perpsAccountTokenReturned = abi.decode(results[0], (address));

        // it should return a valid results array
        assertEq(perpsAccountTokenReturned, address(perpsAccountToken), "createPerpsAccountAndMulticall");
    }

    function testFuzz_CreatePerpsAccountAndDepositMargin(uint256 amountToDeposit)
        external
        whenTheDataArrayDoesNotProvideARevertingCall
    {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        bytes[] memory data = new bytes[](1);
        data[0] =
            abi.encodeWithSelector(IPerpsAccountModule.depositMargin.selector, address(usdToken), amountToDeposit);
        uint128 expectedAccountId = 1;

        // it should emit {LogDepositMargin}
        // vm.expectEmit({ emitter: address(perpsEngine) });
        // emit LogDepositMargin(users.naruto, expectedAccountId, address(usdToken), amountToDeposit);

        // it should transfer the amount from the sender to the perps account
        expectCallToTransferFrom(usdToken, users.naruto, address(perpsEngine), amountToDeposit);
        bytes[] memory results = perpsEngine.createPerpsAccountAndMulticall(data);

        bytes[] memory mockResults = new bytes[](1);

        // console.log(results[0]);

        uint256 newMarginCollateralBalance =
            perpsEngine.getAccountMarginCollateralBalance(expectedAccountId, address(usdToken)).intoUint256();

        // it should increase the amount of margin collateral
        assertEq(results.length, 1, "createPerpsAccountAndMulticall: results");
        assertEq(newMarginCollateralBalance, amountToDeposit, "createPerpsAccountAndMulticall: account margin");
    }
}
