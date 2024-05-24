// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Constants } from "@zaros/utils/Constants.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { convert as ud60x18Convert, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract GetFundingRate_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_GivenTheresAMarketCreated(
        uint128 marketId,
        uint256 marginValueUsd,
        bool isLong,
        uint256 timeElapsed
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });
        timeElapsed = bound({ x: timeElapsed, min: 1 seconds, max: 365 days });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint256 initialMarginRate = ud60x18(fuzzMarketConfig.imr).mul(ud60x18(1.001e18)).intoUint256();
        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsd, isLong);

        skip(timeElapsed);

        // it should return the funding rate
        SD59x18 fundingRate = perpsEngine.getFundingRate(fuzzMarketConfig.marketId);
        SD59x18 fundingVelocity = perpsEngine.getFundingVelocity(fuzzMarketConfig.marketId);
        int256 expectedFundingRate = fundingVelocity.mul(ud60x18Convert(timeElapsed).intoSD59x18()).div(
            ud60x18Convert(Constants.PROPORTIONAL_FUNDING_PERIOD).intoSD59x18()
        ).intoInt256();

        assertEq(fundingRate.intoInt256(), expectedFundingRate, "invalid funding rate");
    }
}
