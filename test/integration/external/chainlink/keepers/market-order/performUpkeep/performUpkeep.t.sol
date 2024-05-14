// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { GlobalConfigurationBranch } from "@zaros/perpetuals/branches/GlobalConfigurationBranch.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { SettlementBranch } from "@zaros/perpetuals/branches/SettlementBranch.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { Markets } from "script/markets/Markets.sol";
import { Log as AutomationLog } from "@zaros/external/chainlink/interfaces/ILogAutomation.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";

import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

contract MarketOrderKeeper_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    modifier givenInitializeContract() {
        _;
    }

    function testFuzz_GivenCallPerformUpkeepFunction(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenInitializeContract
    {
        changePrank({ msgSender: users.naruto });

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });

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
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            OrderBranch.CreateMarketOrderParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);

        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        changePrank({ msgSender: users.owner });
        MarketOrderKeeper(marketOrderKeeper).setForwarder(marketOrderKeeper);

        bytes memory performData = abi.encode(mockSignedReport, abi.encode(tradingAccountId));

        UD60x18 firstFillPriceX18 =
            perpsEngine.getMarkPrice(fuzzMarketConfig.marketId, fuzzMarketConfig.mockUsdPrice, sizeDelta);

        (,,, SD59x18 firstOrderFeeUsdX18,,) = perpsEngine.simulateTrade(
            tradingAccountId,
            fuzzMarketConfig.marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            sizeDelta
        );

        int256 firstOrderExpectedPnl =
            unary(firstOrderFeeUsdX18.add(ud60x18(DEFAULT_SETTLEMENT_FEE).intoSD59x18())).intoInt256();

        // it should emit {LogSettleOrder} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit SettlementBranch.LogFillOrder(
            marketOrderKeeper,
            tradingAccountId,
            fuzzMarketConfig.marketId,
            sizeDelta,
            firstFillPriceX18.intoUint256(),
            firstOrderFeeUsdX18.intoInt256(),
            DEFAULT_SETTLEMENT_FEE,
            firstOrderExpectedPnl,
            0
        );

        changePrank({ msgSender: marketOrderKeeper });
        MarketOrderKeeper(marketOrderKeeper).performUpkeep(performData);
    }

}
