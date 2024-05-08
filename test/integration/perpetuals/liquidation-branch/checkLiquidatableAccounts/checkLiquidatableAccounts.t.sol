// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { IOrderBranch } from "@zaros/perpetuals/interfaces/IOrderBranch.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract CheckLiquidatableAccounts_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_WhenTheBoundsAreZero(uint256 marketId, uint256 marginValueUsd, bool isLong) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        // adjusted margin requirement
        uint256 initialMarginRate = ud60x18(fuzzMarketConfig.marginRequirements).mul(ud60x18(1.001e18)).intoUint256();

        _openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsd, isLong);

        uint256 lowerBound = 0;
        uint256 upperBound = 0;

        uint128[] memory liquidatableAccountIds = perpsEngine.checkLiquidatableAccounts(lowerBound, upperBound);

        // it should return an empty array
        assertEq(liquidatableAccountIds.length, 0, "checkLiquidatableAccounts: return length ");
    }

    function testFuzz_WhenTheresNoLiquidatableAccount(
        uint256 marketId,
        bool isLong,
        uint256 amountOfTradingAccounts
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        amountOfTradingAccounts = bound({ x: amountOfTradingAccounts, min: 1, max: 100 });
        uint256 marginValueUsd = 1_000_000e18 / amountOfTradingAccounts;

        // adjusted margin requirement
        uint256 initialMarginRate = ud60x18(fuzzMarketConfig.marginRequirements).mul(ud60x18(1.001e18)).intoUint256();

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        for (uint256 i = 0; i < amountOfTradingAccounts; i++) {
            uint256 accountMarginValueUsd = marginValueUsd / amountOfTradingAccounts;
            uint128 tradingAccountId = createAccountAndDeposit(accountMarginValueUsd, address(usdToken));
            _openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, accountMarginValueUsd, isLong);
        }

        uint256 lowerBound = 0;
        uint256 upperBound = amountOfTradingAccounts - 1;

        // it should return an empty array
        uint128[] memory liquidatableAccountIds = perpsEngine.checkLiquidatableAccounts(lowerBound, upperBound);

        // it should return an empty array
        assertEq(liquidatableAccountIds.length, 0, "checkLiquidatableAccounts: return length ");
    }

    function test_WhenThereAreOneOrManyLiquidatableAccounts(
        uint256 marketId,
        uint256 marginValueUsd,
        bool isLong,
        uint256 amountOfTradingAccounts
    )
        external
    {
        // MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        // marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        // deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        // uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        // // adjusted margin requirement
        // uint256 initialMarginRate =
        // ud60x18(fuzzMarketConfig.marginRequirements).mul(ud60x18(1.001e18)).intoUint256();

        // _openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsd, isLong);

        // uint256 lowerBound = 0;
        // uint256 upperBound = 1;

        // // it should return an empty array
        // uint128[] memory liquidatableAccountIds = perpsEngine.checkLiquidatableAccounts(lowerBound, upperBound);
        // it should return an array with the liquidatable accounts ids
    }

    function _openPosition(
        MarketConfig memory fuzzMarketConfig,
        uint128 tradingAccountId,
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong
    )
        private
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
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        // first market order
        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
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
}
