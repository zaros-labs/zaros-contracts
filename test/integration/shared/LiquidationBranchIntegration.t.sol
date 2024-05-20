// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract LiquidationBranch_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public virtual override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    function _openPosition(
        MarketConfig memory fuzzMarketConfig,
        uint128 tradingAccountId,
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong
    )
        internal
    {
        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

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

        // first market order
        perpsEngine.createMarketOrder(
            OrderBranch.CreateMarketOrderParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);

        changePrank({ msgSender: marketOrderKeeper });

        // fill first order and open position
        perpsEngine.fillMarketOrder(tradingAccountId, fuzzMarketConfig.marketId, feeRecipients, mockSignedReport);

        changePrank({ msgSender: users.naruto });
    }

    function _setAccountsAsLiquidatable(MarketConfig memory fuzzMarketConfig, bool isLong) internal {
        // TODO: switch to maintenance margin rate only
        uint256 priceShiftBps = fuzzMarketConfig.imr;
        uint256 newIndexPrice = isLong
            ? ud60x18(fuzzMarketConfig.mockUsdPrice).mul(ud60x18(1e18).sub(ud60x18(priceShiftBps))).intoUint256()
            : ud60x18(fuzzMarketConfig.mockUsdPrice).mul(ud60x18(1e18).add(ud60x18(priceShiftBps))).intoUint256();

        updateMockPriceFeed(fuzzMarketConfig.marketId, newIndexPrice);
    }
}
