// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract GetPerpsAccountToken_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function test_GivenTheresAnAccountTokenStored() external {
        address expectedPerpsAccountToken = address(perpsAccountToken);
        address perpsAccountToken = perpsEngine.getPerpsAccountToken();

        // it should return the stored account token
        assertEq(perpsAccountToken, expectedPerpsAccountToken, "getPerpsAccountToken");
    }
}
