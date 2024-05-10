// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { LiquidationBranch } from "@zaros/perpetuals/branches/LiquidationBranch.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { LiquidationBranch_Integration_Test } from "../LiquidationBranchIntegration.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract LiquidateAccounts_Integration_Test is LiquidationBranch_Integration_Test {
    function test_RevertGiven_TheSenderIsNotARegisteredLiquidator() external {
        uint128[] memory accountsIds = new uint128[](1);

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.LiquidatorNotRegistered.selector, users.naruto) });
        perpsEngine.liquidateAccounts({
            accountsIds: accountsIds,
            marginCollateralRecipient: users.marginCollateralRecipient,
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
            marginCollateralRecipient: users.marginCollateralRecipient,
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
            marginCollateralRecipient: users.marginCollateralRecipient,
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
        uint256 initialMarginRate = fuzzMarketConfig.marginRequirements;

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128[] memory accountsIds = new uint128[](amountOfTradingAccounts + 1);

        uint256 accountMarginValueUsd = marginValueUsd / (amountOfTradingAccounts + 1);

        for (uint256 i = 0; i < amountOfTradingAccounts; i++) {
            uint128 tradingAccountId = createAccountAndDeposit(accountMarginValueUsd, address(usdToken));

            _openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, accountMarginValueUsd, isLong);

            accountsIds[i] = tradingAccountId;
        }
        _setAccountsAsLiquidatable(fuzzMarketConfig, isLong);

        uint128 nonLiquidatableTradingAccountId = createAccountAndDeposit(accountMarginValueUsd, address(usdToken));
        accountsIds[amountOfTradingAccounts] = nonLiquidatableTradingAccountId;

        changePrank({ msgSender: liquidationKeeper });

        for (uint256 i = 0; i < accountsIds.length; i++) {
            if (accountsIds[i] == nonLiquidatableTradingAccountId) {
                continue;
            }

            Position.State memory positionState =
                perpsEngine.getPositionState(accountsIds[i], fuzzMarketConfig.marketId);
            (SD59x18 marginBalanceUsdX18,, UD60x18 requiredMaintenanceMarginUsdX18,,,) = perpsEngine.simulateTrade(
                accountsIds[i],
                fuzzMarketConfig.marketId,
                SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                -int128(positionState.sizeX18.intoInt256())
            );

            // it should emit a {LogLiquidateAccount} event
            vm.expectEmit({ emitter: address(perpsEngine) });
            uint256 liquidatedCollateralUsd = marginBalanceUsdX18.gt(
                requiredMaintenanceMarginUsdX18.intoSD59x18()
            ) ? marginBalanceUsdX18.intoUD60x18().intoUint256() : requiredMaintenanceMarginUsdX18.intoUint256();
            emit LiquidationBranch.LogLiquidateAccount({
                keeper: liquidationKeeper,
                tradingAccountId: accountsIds[i],
                amountOfOpenPositions: 1,
                requiredMaintenanceMarginUsd: requiredMaintenanceMarginUsdX18.intoUint256(),
                marginBalanceUsd: marginBalanceUsdX18.intoInt256(),
                liquidatedCollateralUsd: liquidatedCollateralUsd,
                liquidationFeeUsd: LIQUIDATION_FEE_USD
            });
        }

        // it should revert
        perpsEngine.liquidateAccounts(accountsIds, users.marginCollateralRecipient, users.settlementFeeRecipient);
    }
}
