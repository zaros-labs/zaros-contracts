// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";

contract AddMarket_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    function testFuzz_RevertWhen_TheMarketIsAlreadyAdded(uint256 marketId) external {
        marketId = bound({ x: marketId, min: INITIAL_MARKET_ID, max: FINAL_MARKET_ID });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.PerpMarketAlreadyEnabled.selector, uint128(marketId))
        });

        perpsEngine.exposed_addMarket(uint128(marketId));
    }

    function testFuzz_WhenTheMarketWasNotAdded(uint256 marketId) external {
        marketId = bound({ x: marketId, min: FINAL_MARKET_ID + 1, max: 1_000_000e18 });

        // it should add the market
        perpsEngine.exposed_addMarket(uint128(marketId));
        perpsEngine.exposed_checkMarketIsEnabled(uint128(marketId));
    }
}
