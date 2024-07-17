// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

import {console} from 'forge-std/console.sol';

contract ValidatePositionsLimit_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_RevertWhen_UserActivePositionsIsGreaterThanOrEqualTheMaxPositionsPerAccount(
        uint256 marketId,
        bool isLong
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        uint256 marginValueUsd = 10_000_000e18;
        uint256 marginValueUsdPerPosition = marginValueUsd / MAX_POSITIONS_PER_ACCOUNT;
        uint256 initialMarginRate = fuzzMarketConfig.imr;

        deal({ token: address(usdz), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdz));

        for(uint i; i < MAX_POSITIONS_PER_ACCOUNT - 1; i++) {
            console.log("---------------------------------------");
            console.log(fuzzMarketConfig.marketId);

            openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsdPerPosition, isLong);

            fuzzMarketConfig = getFuzzMarketConfig(fuzzMarketConfig.marketId + 1);
            initialMarginRate = fuzzMarketConfig.imr;
        }

        uint256 activeMarketsLength = perpsEngine.workaround_getActiveMarketsIdsLength(tradingAccountId);

        assertEq(activeMarketsLength, MAX_POSITIONS_PER_ACCOUNT - 1, "active markets length should be equal to MAX_POSITIONS_PER_ACCOUNT - 1");

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MaxPositionsPerAccountReached.selector, MAX_POSITIONS_PER_ACCOUNT - 1, MAX_POSITIONS_PER_ACCOUNT)
        });

        openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsdPerPosition, isLong);
    }

    function test_WhenUserActivePositionsIsLessThanTheMaxPositionsPerAccount(
        uint256 requiredMaintenanceMarginUsd,
        int256 marginBalanceUsd
    )
        external
    {

    }
}
