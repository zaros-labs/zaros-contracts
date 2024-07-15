// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { PremiumReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";
import { SettlementBranch } from "@zaros/perpetuals/branches/SettlementBranch.sol";
import { PerpMarket } from "@zaros/perpetuals/leaves/PerpMarket.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { Base_Test } from "test/Base.t.sol";
import { TradingAccountHarness } from "test/harnesses/perpetuals/leaves/TradingAccountHarness.sol";
import { GlobalConfigurationHarness } from "test/harnesses/perpetuals/leaves/GlobalConfigurationHarness.sol";
import { PerpMarketHarness } from "test/harnesses/perpetuals/leaves/PerpMarketHarness.sol";
import { PositionHarness } from "test/harnesses/perpetuals/leaves/PositionHarness.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

import { console } from "forge-std/console.sol";

contract Position_IsIncreasing_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner.account });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto.account });
    }

    function test_WhenIsIncreasingIsCalledAndANewPositionIsBeingCreated(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
    {
        // it should return true
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

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

        bool isIncreased = PositionHarness(address(perpsEngine)).exposed_isIncreasing(
            tradingAccountId, fuzzMarketConfig.marketId, sizeDelta
        );

        assertEq(isIncreased, true);
    }

    function test_WhenIsIncreasingIsCalledAndSizeDeltaIsPositiveAndPositionSizeIsPositive(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId
    )
        external
    {
        // it should return true

        // isLong should be true, not fuzzed
        bool isLong = true;

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // size delta should be positive, not fuzzed
        int128 sizeDelta = 10_000;

        openPosition({
            fuzzMarketConfig: fuzzMarketConfig,
            tradingAccountId: tradingAccountId,
            initialMarginRate: initialMarginRate,
            marginValueUsd: marginValueUsd,
            isLong: isLong
        });

        bool isIncreased = PositionHarness(address(perpsEngine)).exposed_isIncreasing(
            tradingAccountId, fuzzMarketConfig.marketId, sizeDelta
        );

        assertEq(isIncreased, true);
    }

    function test_WhenIsIncreasingIsCalledAndSizeDeltaIsNegativeAndPositionSizeIsNegative(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId
    )
        external
    {
        // it should return true

        // isLong should be false, not fuzzed
        bool isLong = false;

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // size delta should be negative, not fuzzed
        int128 sizeDelta = -10_000;

        openPosition({
            fuzzMarketConfig: fuzzMarketConfig,
            tradingAccountId: tradingAccountId,
            initialMarginRate: initialMarginRate,
            marginValueUsd: marginValueUsd,
            isLong: isLong
        });

        bool isIncreased = PositionHarness(address(perpsEngine)).exposed_isIncreasing(
            tradingAccountId, fuzzMarketConfig.marketId, sizeDelta
        );

        assertEq(isIncreased, true);
    }

    function test_WhenIsIncreasingIsCalledAndSizeDeltaIsPositiveAndPositionSizeIsNegative(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId
    )
        external
    {
        // it should return false

        // isLong should be false, not fuzzed
        bool isLong = false;

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // size delta should be positive, not fuzzed
        int128 sizeDelta = 10_000;

        openPosition({
            fuzzMarketConfig: fuzzMarketConfig,
            tradingAccountId: tradingAccountId,
            initialMarginRate: initialMarginRate,
            marginValueUsd: marginValueUsd,
            isLong: isLong
        });

        bool isIncreased = PositionHarness(address(perpsEngine)).exposed_isIncreasing(
            tradingAccountId, fuzzMarketConfig.marketId, sizeDelta
        );

        assertEq(isIncreased, false);
    }

    function test_WhenIsIncreasingIsCalledAndSizeDeltaIsNegativeAndPositionSizeIsPositive(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId
    )
        external
    {
        // it should return false

        // isLong should be false, not fuzzed
        bool isLong = false;

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate = bound({ x: initialMarginRate, min: fuzzMarketConfig.imr, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({
            x: marginValueUsd,
            min: USDC_MIN_DEPOSIT_MARGIN,
            max: convertUd60x18ToTokenAmount(address(usdc), USDC_DEPOSIT_CAP_X18)
        });

        deal({ token: address(usdc), to: users.naruto.account, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdc));

        // size delta should be positive, not fuzzed
        int128 sizeDelta = 10_000;

        openPosition({
            fuzzMarketConfig: fuzzMarketConfig,
            tradingAccountId: tradingAccountId,
            initialMarginRate: initialMarginRate,
            marginValueUsd: marginValueUsd,
            isLong: isLong
        });

        bool isIncreased = PositionHarness(address(perpsEngine)).exposed_isIncreasing(
            tradingAccountId, fuzzMarketConfig.marketId, sizeDelta
        );

        assertEq(isIncreased, false);
    }
}
