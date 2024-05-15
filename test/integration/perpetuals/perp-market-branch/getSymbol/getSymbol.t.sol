// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

contract PerpMarketBranchGetSymbol_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_WhenCallGetNameFunctionPassingTheMarketId(uint256 marketId) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // it should return the symbol of market
        string memory marketSymbol = perpsEngine.getSymbol(fuzzMarketConfig.marketId);

        assertEq(fuzzMarketConfig.marketSymbol, marketSymbol, "Invalid market symbol");
    }
}
