// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { SD59x18 } from "@prb-math/UD60x18.sol";

contract PerpMarketBranchGetSkew_Integration_Test is Base_Integration_Shared_Test{
     function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_WhenCallGetSkewFunctionPassingTheMarketId(uint256 marketId) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // TODO
        // it should return the kew
    }
}
