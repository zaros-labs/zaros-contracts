// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

contract Fee_Uniswap_SetPoolFee_Unit_Test is Base_Test {
    function setUp() public virtual override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        createVault();
        changePrank({ msgSender: address(perpsEngine) });
    }

    function test_RevertWhen_PoolFeeIsPassedValueLessThan1000() external {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InvalidPoolFee.selector) });
        marketMakingEngine.exposed_setPoolFee(500);
    }

    function test_WhenPoolFeeIsPassedValidValue() external {
        // it should set pool fee
        marketMakingEngine.exposed_setPoolFee(1000);
    }
}
