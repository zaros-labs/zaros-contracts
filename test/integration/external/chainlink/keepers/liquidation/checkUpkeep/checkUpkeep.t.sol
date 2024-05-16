// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { LiquidationKeeper } from "@zaros/external/chainlink/keepers/liquidation/LiquidationKeeper.sol";
import { LiquidationBranch_Integration_Test } from "test/integration/shared/LiquidationBranchIntegration.t.sol";

contract LiquidationKeeper_CheckUpkeep_Integration_Test is LiquidationBranch_Integration_Test {
    function testFuzz_RevertWhen_TheCheckLowerBoundIsHigherThanTheCheckUpperBound(
        uint256 checkLowerBound,
        uint256 checkUpperBound,
        uint256 performLowerBound,
        uint256 performUpperBound
    )
        external
    {
        checkLowerBound = bound({ x: checkLowerBound, min: 1, max: 1000 });
        checkUpperBound = bound({ x: checkUpperBound, min: 0, max: checkLowerBound - 1 });
        performLowerBound = bound({ x: performLowerBound, min: 0, max: 1000 });
        performUpperBound = bound({ x: performUpperBound, min: performLowerBound + 1, max: performLowerBound + 16 });

        bytes memory checkData = abi.encode(checkLowerBound, checkUpperBound, performLowerBound, performUpperBound);

        // it should revert
        vm.expectRevert({ revertData: Errors.InvalidBounds.selector });
        LiquidationKeeper(liquidationKeeper).checkUpkeep(checkData);
    }

    modifier whenTheCheckLowerBoundIsLowerThanTheCheckUpperBound() {
        _;
    }

    function testFuzz_RevertWhen_ThePerformLowerBoundIsHigherThanThePerformUpperBound(
        uint256 checkLowerBound,
        uint256 checkUpperBound,
        uint256 performLowerBound,
        uint256 performUpperBound
    )
        external
        whenTheCheckLowerBoundIsLowerThanTheCheckUpperBound
    {
        checkLowerBound = bound({ x: checkLowerBound, min: 0, max: 1000 });
        checkUpperBound = bound({ x: checkUpperBound, min: checkLowerBound + 1, max: checkLowerBound + 101 });
        performLowerBound = bound({ x: performLowerBound, min: 1, max: 1000 });
        performUpperBound = bound({ x: performUpperBound, min: 0, max: performLowerBound - 1 });

        bytes memory checkData = abi.encode(checkLowerBound, checkUpperBound, performLowerBound, performUpperBound);

        // it should revert
        vm.expectRevert({ revertData: Errors.InvalidBounds.selector });
        LiquidationKeeper(liquidationKeeper).checkUpkeep(checkData);
    }

    modifier whenThePerformLowerBoundIsLowerThanThePerformUpperBound() {
        _;
    }

    function testFuzz_GivenThereAreNoLiquidatableAccountsIds(
        uint256 checkLowerBound,
        uint256 checkUpperBound,
        uint256 performLowerBound,
        uint256 performUpperBound
    )
        external
        whenTheCheckLowerBoundIsLowerThanTheCheckUpperBound
        whenThePerformLowerBoundIsLowerThanThePerformUpperBound
    {
        checkLowerBound = bound({ x: checkLowerBound, min: 0, max: 1000 });
        checkUpperBound = bound({ x: checkUpperBound, min: checkLowerBound + 1, max: checkLowerBound + 101 });
        performLowerBound = bound({ x: performLowerBound, min: 0, max: 1000 });
        performUpperBound = bound({ x: performUpperBound, min: performLowerBound + 1, max: performLowerBound + 16 });

        bytes memory checkData = abi.encode(checkLowerBound, checkUpperBound, performLowerBound, performUpperBound);

        (bool upkeepNeeded, bytes memory performData) = LiquidationKeeper(liquidationKeeper).checkUpkeep(checkData);

        // it should return upkeepNeeded == false
        assertFalse(upkeepNeeded, "upkeepNeeded");
        uint128[] memory liquidatableAccountsIds = abi.decode(performData, (uint128[]));

        for (uint256 i = 0; i < liquidatableAccountsIds.length; i++) {
            assertEq(liquidatableAccountsIds[i], 0, "liquidatableAccountsIds");
        }
    }

    function testFuzz_GivenThereAreLiquidatableAccounts(
        uint256 checkLowerBound,
        uint256 checkUpperBound,
        uint256 performLowerBound,
        uint256 performUpperBound,
        uint256 marketId,
        uint256 amountOfTradingAccounts,
        bool isLong
    )
        external
        whenTheCheckLowerBoundIsLowerThanTheCheckUpperBound
        whenThePerformLowerBoundIsLowerThanThePerformUpperBound
    {
        // checkLowerBound = bound({ x: checkLowerBound, min: 0, max: 1000 });
        // checkUpperBound = bound({ x: checkUpperBound, min: checkLowerBound + 1, max: checkLowerBound + 101 });
        // performLowerBound = bound({ x: performLowerBound, min: 0, max: 1000 });
        // performUpperBound = bound({ x: performUpperBound, min: performLowerBound + 1, max: performLowerBound + 16
        // });

        // MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        // amountOfTradingAccounts = bound({ x: amountOfTradingAccounts, min: 1, max: 10 });
        // uint256 marginValueUsd = 10_000e18 / amountOfTradingAccounts;
        // uint256 initialMarginRate = fuzzMarketConfig.marginRequirements;

        // bytes memory checkData = abi.encode(checkLowerBound, checkUpperBound, performLowerBound,
        // performUpperBound);

        // deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        // for (uint256 i = 0; i < amountOfTradingAccounts; i++) {
        //     uint256 accountMarginValueUsd = marginValueUsd / amountOfTradingAccounts;
        //     uint128 tradingAccountId = createAccountAndDeposit(accountMarginValueUsd, address(usdToken));

        //     _openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, accountMarginValueUsd, isLong);
        // }
        // _setAccountsAsLiquidatable(fuzzMarketConfig, isLong);

        // (bool upkeepNeeded, bytes memory performData) =
        // LiquidationKeeper(liquidationKeeper).checkUpkeep(checkData);

        // // it should return upkeepNeeded == true
        // assertTrue(upkeepNeeded, "upkeepNeeded ");
        // // it should return the abi encoded liquidatable accounts ids
        // uint128[] memory liquidatableAccountsIds = abi.decode(performData, (uint128[]));

        // for (uint256 i = 0; i < liquidatableAccountsIds.length; i++) {
        //     assertEq(liquidatableAccountsIds[i], i + 1, "liquidatableAccountsIds");
        // }
    }
}
