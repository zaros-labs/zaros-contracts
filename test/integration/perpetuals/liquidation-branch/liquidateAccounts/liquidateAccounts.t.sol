// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { LiquidationBranch } from "@zaros/perpetuals/branches/LiquidationBranch.sol";
import { LiquidationBranch_Integration_Test } from "../LiquidationBranchIntegration.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";

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

            // it should emit a {LogLiquidateAccount} event
            vm.expectEmit({ emitter: address(perpsEngine) });
            emit LiquidationBranch.LogLiquidateAccount({
                keeper: liquidationKeeper,
                tradingAccountId: accountsIds[i],
                amountOfOpenPositions: 1,
                requiredMaintenanceMarginUsd: accountMarginValueUsd,
                marginBalanceUsd: int256(accountMarginValueUsd),
                liquidatedCollateralUsd: accountMarginValueUsd,
                liquidationFeeUsd: LIQUIDATION_FEE_USD,
                liquidationFeeRecipient: users.settlementFeeRecipient,
                marginCollateralRecipient: users.marginCollateralRecipient
            });

        }

        // it should revert
        perpsEngine.liquidateAccounts(accountsIds, users.marginCollateralRecipient, users.settlementFeeRecipient);
    }
}
