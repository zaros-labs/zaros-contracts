// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract Position_GetAccruedFunding_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
    }

    function testFuzz_WhenGetAccruedFundingIsCalled(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId,
        bool isLong
    )
        external
    {
        changePrank({ msgSender: users.naruto });

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });
        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsd, isLong);

        Position.Data memory position = perpsEngine.exposed_Position_load(tradingAccountId, fuzzMarketConfig.marketId);

        SD59x18 fundingFeePerUnitX18 = sd59x18(1e18);
        SD59x18 netFundingFeePerUnit = fundingFeePerUnitX18.sub(sd59x18(position.lastInteractionFundingFeePerUnit));
        SD59x18 expectedAccruedFundingUsdX18 = sd59x18(position.size).mul(netFundingFeePerUnit);

        SD59x18 accruedFundingUsdX18 =
            perpsEngine.exposed_getAccruedFunding(tradingAccountId, fuzzMarketConfig.marketId, fundingFeePerUnitX18);

        // it should return the accrued funding usd
        assertEq(
            expectedAccruedFundingUsdX18.intoInt256(),
            accruedFundingUsdX18.intoInt256(),
            "Invalid accrued funding usd"
        );
    }
}
