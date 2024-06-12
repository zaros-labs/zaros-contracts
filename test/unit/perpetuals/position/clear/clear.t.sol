// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract Position_Clear_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
    }

    function testFuzz_WhenClearIsCalled(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
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

        openPosition(fuzzMarketConfig, tradingAccountId, initialMarginRate, marginValueUsd, isLong);

        perpsEngine.exposed_clear(tradingAccountId, fuzzMarketConfig.marketId);

        Position.Data memory position = perpsEngine.exposed_Position_load(tradingAccountId, fuzzMarketConfig.marketId);

        // it should return the size equal to zero
        assertEq(0, position.size, "size should be zero");

        // it should return the lastInteractionPrice equal to zero
        assertEq(0, position.lastInteractionPrice, "lastInteractionPrice should be zero");

        // it should return the lastInteractionFundingFeePerUnit equal to zero
        assertEq(0, position.lastInteractionFundingFeePerUnit, "lastInteractionFundingFeePerUnit should be zero");
    }
}
