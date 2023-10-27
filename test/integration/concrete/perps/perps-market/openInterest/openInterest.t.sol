// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { IPerpsAccountModule } from "@zaros/markets/perps/interfaces/IPerpsAccountModule.sol";
import { ParameterError } from "@zaros/utils/Errors.sol";

contract CreatePerpsAccountAndMulticall_Integration_Concrete_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function test_RevertWhen_RevertingCallProvided() external {
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(IPerpsAccountModule.depositMargin.selector, address(usdToken), uint256(0));
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                ParameterError.Zaros_InvalidParameter.selector, "amount", "amount can't be zero"
                )
        });
        perpsEngine.createPerpsAccountAndMulticall(data);
    }

    modifier whenNonRevertingCall() {
        _;
    }

    function test_NullDataArray() external whenNonRevertingCall {
        bytes[] memory data = new bytes[](0);
        uint256 expectedAccountId = 1;
        uint256 expectedResultsLength = 0;

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);

        bytes[] memory results = perpsEngine.createPerpsAccountAndMulticall(data);
        assertEq(results.length, expectedResultsLength, "createPerpsAccountAndMulticall");
    }

    function test_ValidDataArray() external whenNonRevertingCall {
        bytes[] memory data = new bytes[](1);
        uint256 expectedAccountId = 1;
        data[0] = abi.encodeWithSelector(IPerpsAccountModule.getPerpsAccountTokenAddress.selector);

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreatePerpsAccount(expectedAccountId, users.naruto);

        bytes[] memory results = perpsEngine.createPerpsAccountAndMulticall(data);
        address perpsAccountTokenReturned = abi.decode(results[0], (address));

        assertEq(perpsAccountTokenReturned, address(perpsAccountToken), "createPerpsAccountAndMulticall");
    }
}
