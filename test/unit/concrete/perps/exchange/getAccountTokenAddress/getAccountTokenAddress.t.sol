// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract GetAccountTokenAddress_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_PerpsAccountTokenStored() external {
        address expectedPerpsAccountToken = address(perpsAccountToken);
        address perpsAccountToken = perpsEngine.getPerpsAccountTokenAddress();

        assertEq(perpsAccountToken, expectedPerpsAccountToken, "getPerpsAccountTokenAddress");
    }
}
