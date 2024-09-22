// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract Fee_SetSlippageTolerance_Unit_Test is Base_Test {
    function test_RevertWhen_SlippageIsPassedZeroValue() external {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidSlippage.selector) });
        marketMakingEngine.exposed_setSlippageTolerance(0);
    }

    function test_WhenSlippageIsPassedValueOtherThanZero() external {
        // it should set slippage
        marketMakingEngine.exposed_setSlippageTolerance(100);
    }
}
