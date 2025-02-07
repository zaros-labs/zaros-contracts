// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { OrderFees } from "@zaros/perpetuals/leaves/OrderFees.sol";

contract GetConfiguredOrderFees_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function testFuzz_GivenTheresAMarketCreated(uint256 marketId) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // it should return the maker fee
        // it should return the taker fee
        OrderFees.Data memory orderFees = perpsEngine.getConfiguredOrderFees((fuzzMarketConfig.marketId));

        assertEq(orderFees.makerFee, fuzzMarketConfig.orderFees.makerFee);
        assertEq(orderFees.takerFee, fuzzMarketConfig.orderFees.takerFee);
    }
}
