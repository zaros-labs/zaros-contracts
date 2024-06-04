// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract Position_Update_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
    }

    function testFuzz_WhenUpdateIsCalled(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId,
        int256 newSize,
        uint128 newLastInteractionPrice,
        int128 newLastInteractionFundingFeePerUnit
    )
        external
    {
        changePrank({ msgSender: users.naruto });

        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        Position.Data memory newPosition = Position.Data({
            size: newSize,
            lastInteractionPrice: newLastInteractionPrice,
            lastInteractionFundingFeePerUnit: newLastInteractionFundingFeePerUnit
        });

        perpsEngine.exposed_update(tradingAccountId, fuzzMarketConfig.marketId, newPosition);

        Position.Data memory position = perpsEngine.exposed_Position_load(tradingAccountId, fuzzMarketConfig.marketId);

        // it should update the size
        assertEq(position.size, newSize, "Position size not updated");

        // it should update the lastInteractionPrice
        assertEq(position.lastInteractionPrice, newLastInteractionPrice, "Position lastInteractionPrice not updated");

        // it should update the lastInteractionFundingFeePerUnit
        assertEq(
            position.lastInteractionFundingFeePerUnit,
            newLastInteractionFundingFeePerUnit,
            "Position lastInteractionFundingFeePerUnit not updated"
        );
    }
}
