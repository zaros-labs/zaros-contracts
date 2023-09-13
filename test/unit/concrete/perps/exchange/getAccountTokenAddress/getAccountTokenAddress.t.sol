// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract CreatePerpsAccount_Unit_Concrete_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_PerpsAccountTokenStored() external {
        address expectedPerpsAccountToken = address(perpsPerpsAccountToken);
        address perpsPerpsAccountToken = perpsExchange.getPerpsAccountTokenAddress();

        assertEq(perpsPerpsAccountToken, expectedPerpsAccountToken, "getPerpsAccountTokenAddress");
    }
}
