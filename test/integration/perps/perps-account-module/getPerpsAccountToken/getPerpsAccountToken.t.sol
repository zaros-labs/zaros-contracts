// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

contract GetPerpsAccountToken_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
    }

    function test_GivenTheresAnAccountTokenStored() external {
        address expectedPerpsAccountToken = address(perpsAccountToken);
        address perpsAccountToken = perpsEngine.getPerpsAccountToken();

        // it should return the stored account token
        assertEq(perpsAccountToken, expectedPerpsAccountToken, "getPerpsAccountToken");
    }
}
