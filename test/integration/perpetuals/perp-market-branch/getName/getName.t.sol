// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract GetName_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function testFuzz_GivenTheresAMarketCreated(uint256 marketId) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // it should return the name of market
        string memory marketName = perpsEngine.getName(fuzzMarketConfig.marketId);

        assertEq(fuzzMarketConfig.marketName, marketName, "Invalid market name");
    }
}
