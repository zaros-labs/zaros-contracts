// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsAccountModule } from "@zaros/markets/perps/interfaces/IPerpsAccountModule.sol";
import { ParameterError } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";

contract CreatePerpsAccountAndMulticall_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        approveContracts();
        changePrank({ msgSender: users.naruto });
    }

    function test_RevertWhen_RevertingCallProvided() external {
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(IPerpsAccountModule.depositMargin.selector, address(zrsUsd), uint256(0));
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                ParameterError.Zaros_InvalidParameter.selector, "amount", "amount can't be zero"
                )
        });
        perpsExchange.createPerpsAccountAndMulticall(data);
    }

    modifier whenNonRevertingCall() {
        _;
    }

    function test_NullDataArray() external whenNonRevertingCall {
        bytes[] memory data = new bytes[](0);
        uint256 expectedAccountId = 1;
        uint256 expectedResultsLength = 0;

        vm.expectEmit({ emitter: address(perpsExchange) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);

        bytes[] memory results = perpsExchange.createPerpsAccountAndMulticall(data);
        assertEq(results.length, expectedResultsLength, "createPerpsAccountAndMulticall");
    }

    function test_ValidDataArray() external whenNonRevertingCall {
        bytes[] memory data = new bytes[](1);
        uint256 expectedAccountId = 1;
        data[0] = abi.encodeWithSelector(IPerpsAccountModule.getPerpsAccountTokenAddress.selector);

        vm.expectEmit({ emitter: address(perpsExchange) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);

        bytes[] memory results = perpsExchange.createPerpsAccountAndMulticall(data);
        address perpsAccountTokenReturned = abi.decode(results[0], (address));

        assertEq(perpsAccountTokenReturned, address(perpsAccountToken), "createPerpsAccountAndMulticall");
    }
}
