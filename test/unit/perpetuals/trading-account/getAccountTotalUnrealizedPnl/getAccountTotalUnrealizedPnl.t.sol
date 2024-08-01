// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";

// PRB Math dependencies
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract GetAccountTotalUnrealizedPnl_Unit_Tests is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function testFuzz_WhenThereIsActiveMarketIds(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint128 marketId,
        bool isLong
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // open an existing position to enter the if check
        openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsd, isLong);

        // int128 sizeDelta = fuzzOrderSizeDelta(
        //     FuzzOrderSizeDeltaParams({
        //         tradingAccountId: tradingAccountId,
        //         marketId: fuzzMarketConfig.marketId,
        //         settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
        //         initialMarginRate: ud60x18(initialMarginRate),
        //         marginValueUsd: ud60x18(marginValueUsd),
        //         maxSkew: ud60x18(fuzzMarketConfig.maxSkew),
        //         minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
        //         price: ud60x18(fuzzMarketConfig.mockUsdPrice),
        //         isLong: isLong,
        //         shouldDiscountFees: true
        //     })
        // );

        int128 sizeDelta = 100_000;

        perpsEngine.exposed_update(tradingAccountId, fuzzMarketConfig.marketId, sizeDelta);

        // it should return the total unrealized PnL of the trading account
        SD59x18 totalUnrealizedPnlUsdX18 = perpsEngine.getAccountTotalUnrealizedPnl(tradingAccountId);

        assertNotEq(totalUnrealizedPnlUsdX18.intoUint256(), 0);
    }

    function testFuzz_WhenThereIsNoActiveMarketIds() external {
        // it should return zero in SD59x18 format
    }
}
