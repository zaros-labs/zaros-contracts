// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract GetMarginRequirementForTrade_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    function test_GivenTheresAMarketCreated(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxSkew: ud60x18(fuzzMarketConfig.maxSkew),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        UD60x18 markPriceX18 =
            perpsEngine.getMarkPrice(fuzzMarketConfig.marketId, fuzzMarketConfig.mockUsdPrice, sizeDelta);

        UD60x18 orderValueX18 = markPriceX18.mul(sd59x18(sizeDelta).abs().intoUD60x18());

        UD60x18 expectedInitialMarginUsd = orderValueX18.mul(ud60x18(fuzzMarketConfig.imr));
        UD60x18 expectedMaintenanceMarginUsd = orderValueX18.mul(ud60x18(fuzzMarketConfig.mmr));

        (UD60x18 initialMarginUsdX18, UD60x18 maintenanceMarginUsdX18) =
            perpsEngine.getMarginRequirementForTrade(fuzzMarketConfig.marketId, sizeDelta);

        // it should return the initial margin usd
        assertEq(
            initialMarginUsdX18.intoUint256(),
            expectedInitialMarginUsd.intoUint256(),
            "initial margin usd is not correct"
        );

        // it should return the maintenance margin usd
        assertEq(
            maintenanceMarginUsdX18.intoUint256(),
            expectedMaintenanceMarginUsd.intoUint256(),
            "maintenance margin usd is not correct"
        );
    }
}
