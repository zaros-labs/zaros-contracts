// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";

contract GetSymbol_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function testFuzz_GivenTheresAMarketCreated(uint256 marketId) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // it should return the symbol of market
        string memory marketSymbol = perpsEngine.getSymbol(fuzzMarketConfig.marketId);

        assertEq(fuzzMarketConfig.marketSymbol, marketSymbol, "Invalid market symbol");
    }
}
