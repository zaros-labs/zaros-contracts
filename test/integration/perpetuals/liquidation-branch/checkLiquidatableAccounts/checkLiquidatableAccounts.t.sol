// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { LiquidationBranch_Integration_Test } from "../LiquidationBranchIntegration.t.sol";

contract CheckLiquidatableAccounts_Integration_Test is LiquidationBranch_Integration_Test {
    function testFuzz_WhenTheBoundsAreZero(uint256 marketId, uint256 marginValueUsd, bool isLong) external {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        uint256 initialMarginRate = fuzzMarketConfig.marginRequirements;

        _openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsd, isLong);

        uint256 lowerBound = 0;
        uint256 upperBound = 0;

        uint128[] memory liquidatableAccountIds = perpsEngine.checkLiquidatableAccounts(lowerBound, upperBound);

        // it should return an empty array
        assertEq(liquidatableAccountIds.length, 0);
    }

    function testFuzz_WhenTheresNoLiquidatableAccount(
        uint256 marketId,
        bool isLong,
        uint256 amountOfTradingAccounts
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        amountOfTradingAccounts = bound({ x: amountOfTradingAccounts, min: 1, max: 10 });
        uint256 marginValueUsd = 1_000_000e18 / amountOfTradingAccounts;
        uint256 initialMarginRate = fuzzMarketConfig.marginRequirements;

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        for (uint256 i = 0; i < amountOfTradingAccounts; i++) {
            uint256 accountMarginValueUsd = marginValueUsd / amountOfTradingAccounts;
            uint128 tradingAccountId = createAccountAndDeposit(accountMarginValueUsd, address(usdToken));
            _openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, accountMarginValueUsd, isLong);
        }

        uint256 lowerBound = 0;
        uint256 upperBound = amountOfTradingAccounts;

        // it should return an empty array
        uint128[] memory liquidatableAccountIds = perpsEngine.checkLiquidatableAccounts(lowerBound, upperBound);

        // it should return an empty array
        for (uint256 i = 0; i < liquidatableAccountIds.length; i++) {
            assertEq(liquidatableAccountIds[i], 0);
        }
    }

    function testFuzz_WhenThereAreOneOrManyLiquidatableAccounts(
        uint256 marketId,
        bool isLong,
        uint256 amountOfTradingAccounts
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        amountOfTradingAccounts = bound({ x: amountOfTradingAccounts, min: 1, max: 10 });
        uint256 marginValueUsd = 10_000e18 / amountOfTradingAccounts;
        uint256 initialMarginRate = fuzzMarketConfig.marginRequirements;

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        for (uint256 i = 0; i < amountOfTradingAccounts; i++) {
            uint256 accountMarginValueUsd = marginValueUsd / amountOfTradingAccounts;
            uint128 tradingAccountId = createAccountAndDeposit(accountMarginValueUsd, address(usdToken));

            _openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, accountMarginValueUsd, isLong);
        }
        _setAccountsAsLiquidatable(fuzzMarketConfig, isLong);

        uint256 lowerBound = 0;
        uint256 upperBound = amountOfTradingAccounts;

        uint128[] memory liquidatableAccountIds = perpsEngine.checkLiquidatableAccounts(lowerBound, upperBound);

        assertEq(liquidatableAccountIds.length, amountOfTradingAccounts);
        for (uint256 i = 0; i < liquidatableAccountIds.length; i++) {
            // it should return an array with the liquidatable accounts ids
            assertEq(liquidatableAccountIds[i], i + 1);
        }
    }
}
