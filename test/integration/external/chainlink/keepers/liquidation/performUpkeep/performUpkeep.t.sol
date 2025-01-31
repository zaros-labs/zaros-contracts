// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Test } from "test/Base.t.sol";
import { LiquidationKeeper } from "@zaros/external/chainlink/keepers/liquidation/LiquidationKeeper.sol";
import { LiquidationBranch } from "@zaros/perpetuals/branches/LiquidationBranch.sol";

contract LiquidationKeeper_PerformUpkeep_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
    }

    modifier givenInitializeContract() {
        _;
    }

    function testFuzz_GivenCallPerformUpkeepFunction(
        uint256 marketId,
        bool isLong,
        uint256 amountOfTradingAccounts
    )
        external
        givenInitializeContract
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        amountOfTradingAccounts = bound({ x: amountOfTradingAccounts, min: 1, max: 10 });
        uint256 marginValueUsd = 10_000e18 / amountOfTradingAccounts;
        uint256 initialMarginRate = fuzzMarketConfig.imr;

        deal({ token: address(usdToken), to: users.naruto.account, give: marginValueUsd });

        uint128[] memory accountsIds = new uint128[](amountOfTradingAccounts + 1);

        uint256 accountMarginValueUsd = marginValueUsd / (amountOfTradingAccounts + 1);

        for (uint256 i; i < amountOfTradingAccounts; i++) {
            uint128 tradingAccountId = createAccountAndDeposit(accountMarginValueUsd, address(usdToken));

            openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, accountMarginValueUsd, isLong);

            accountsIds[i] = tradingAccountId;
        }
        setAccountsAsLiquidatable(fuzzMarketConfig, isLong);

        uint128 nonLiquidatableTradingAccountId = createAccountAndDeposit(accountMarginValueUsd, address(usdToken));
        accountsIds[amountOfTradingAccounts] = nonLiquidatableTradingAccountId;

        changePrank({ msgSender: users.owner.account });
        LiquidationKeeper(liquidationKeeper).setForwarder(users.keepersForwarder.account);

        changePrank({ msgSender: users.keepersForwarder.account });
        bytes memory performData = abi.encode(accountsIds);

        for (uint256 i; i < accountsIds.length; i++) {
            if (accountsIds[i] == nonLiquidatableTradingAccountId) {
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

        LiquidationKeeper(liquidationKeeper).performUpkeep(performData);
    }
}
