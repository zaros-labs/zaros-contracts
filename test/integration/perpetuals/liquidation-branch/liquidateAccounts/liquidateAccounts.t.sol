// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { LiquidationBranch } from "@zaros/perpetuals/branches/LiquidationBranch.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { TradingAccountHarness } from "test/harnesses/perpetuals/leaves/TradingAccountHarness.sol";
import { GlobalConfigurationHarness } from "test/harnesses/perpetuals/leaves/GlobalConfigurationHarness.sol";
import { PositionHarness } from "test/harnesses/perpetuals/leaves/PositionHarness.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract LiquidateAccounts_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_RevertGiven_TheSenderIsNotARegisteredLiquidator() external {
        uint128[] memory accountsIds = new uint128[](1);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.LiquidatorNotRegistered.selector, users.naruto) });
        perpsEngine.liquidateAccounts({
            accountsIds: accountsIds,
            liquidationFeeRecipient: users.settlementFeeRecipient
        });
    }

    modifier givenTheSenderIsARegisteredLiquidator() {
        _;
    }

    function test_WhenTheAccountsIdsArrayIsEmpty() external givenTheSenderIsARegisteredLiquidator {
        uint128[] memory accountsIds;

        changePrank({ msgSender: liquidationKeeper });

        // it should return
        perpsEngine.liquidateAccounts({
            accountsIds: accountsIds,
            liquidationFeeRecipient: users.settlementFeeRecipient
        });
    }

    modifier whenTheAccountsIdsArrayIsNotEmpty() {
        _;
    }

    function test_RevertGiven_OneOfTheAccountsDoesNotExist()
        external
        givenTheSenderIsARegisteredLiquidator
        whenTheAccountsIdsArrayIsNotEmpty
    {
        uint128[] memory accountsIds = new uint128[](1);
        accountsIds[0] = 1;

        changePrank({ msgSender: liquidationKeeper });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, accountsIds[0], liquidationKeeper)
        });
        perpsEngine.liquidateAccounts({
            accountsIds: accountsIds,
            liquidationFeeRecipient: users.settlementFeeRecipient
        });
    }

    modifier givenAllAccountsExist() {
        _;
    }

    function testFuzz_GivenThereAreLiquidatableAccountsInTheArray(
        uint256 marketId,
        bool isLong,
        uint256 amountOfTradingAccounts
    )
        external
        givenTheSenderIsARegisteredLiquidator
        whenTheAccountsIdsArrayIsNotEmpty
        givenAllAccountsExist
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        amountOfTradingAccounts = bound({ x: amountOfTradingAccounts, min: 1, max: 10 });
        uint256 marginValueUsd = 10_000e18 / amountOfTradingAccounts;
        uint256 initialMarginRate = fuzzMarketConfig.imr;

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        // last account id == 0
        uint128[] memory accountsIds = new uint128[](amountOfTradingAccounts + 2);

        uint256 accountMarginValueUsd = marginValueUsd / (amountOfTradingAccounts + 1);

        for (uint256 i = 0; i < amountOfTradingAccounts; i++) {
            uint128 tradingAccountId = createAccountAndDeposit(accountMarginValueUsd, address(usdToken));

            openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, accountMarginValueUsd, isLong);

            accountsIds[i] = tradingAccountId;
        }
        setAccountsAsLiquidatable(fuzzMarketConfig, isLong);

        uint128 nonLiquidatableTradingAccountId = createAccountAndDeposit(accountMarginValueUsd, address(usdToken));
        accountsIds[amountOfTradingAccounts - 1] = nonLiquidatableTradingAccountId;

        changePrank({ msgSender: liquidationKeeper });

        for (uint256 i = 0; i < accountsIds.length; i++) {
            if (accountsIds[i] == nonLiquidatableTradingAccountId || accountsIds[i] == 0) {
                continue;
            }

            // it should emit a {LogLiquidateAccount} event
            vm.expectEmit({
                checkTopic1: true,
                checkTopic2: true,
                checkTopic3: false,
                checkData: false,
                emitter: address(perpsEngine)
            });

            emit LiquidationBranch.LogLiquidateAccount({
                keeper: liquidationKeeper,
                tradingAccountId: accountsIds[i],
                amountOfOpenPositions: 0,
                requiredMaintenanceMarginUsd: 0,
                marginBalanceUsd: 0,
                liquidatedCollateralUsd: 0,
                liquidationFeeUsd: 0
            });
        }

        perpsEngine.liquidateAccounts(accountsIds, users.settlementFeeRecipient);

        for (uint256 i = 0; i < accountsIds.length; i++) {
            if (accountsIds[i] == nonLiquidatableTradingAccountId) {
                continue;
            }

            // it should delete any active market order
            MarketOrder.Data memory marketOrder = perpsEngine.getActiveMarketOrder(accountsIds[i]);
            assertEq(marketOrder.marketId, 0);
            assertEq(marketOrder.sizeDelta, 0);
            assertEq(marketOrder.timestamp, 0);

            // TODO: funding task
            // it should update the market's funding values

            // it should close all active positions
            Position.Data memory expectedPosition =
                Position.Data({ size: 0, lastInteractionPrice: 0, lastInteractionFundingFeePerUnit: 0 });
            Position.Data memory position =
                PositionHarness(address(perpsEngine)).exposed_Position_load(accountsIds[i], fuzzMarketConfig.marketId);
            assertEq(expectedPosition.size, position.size, "position size");
            assertEq(expectedPosition.lastInteractionPrice, position.lastInteractionPrice, "position price");
            assertEq(
                expectedPosition.lastInteractionFundingFeePerUnit,
                position.lastInteractionFundingFeePerUnit,
                "position funding fee"
            );

            // it should remove the account's all active markets
            assertEq(
                0,
                TradingAccountHarness(address(perpsEngine)).workaround_getActiveMarketsIdsLength(accountsIds[i]),
                "active market id"
            );
            // we only have one account still active
            assertEq(
                1,
                GlobalConfigurationHarness(address(perpsEngine)).workaround_getAccountsIdsWithActivePositionsLength(),
                "accounts ids with active positions"
            );

            // it should update open interest value
            (,, UD60x18 openInterestX18) = perpsEngine.getOpenInterest(marketOrder.marketId);
            assertEq(0, openInterestX18.intoUint256(), "open interest value should be zero");

            // it should update skew value
            SD59x18 skewX18 = perpsEngine.getSkew(marketOrder.marketId);
            assertEq(0, skewX18.intoInt256(), "skew value should be zero");
        }
    }
}
