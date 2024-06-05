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
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract Position_GetUnrealizedPnl_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
    }

    function testFuzz_WhenGetUnrealizedPnlIsCalled(
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

        Position.Data memory position = perpsEngine.exposed_Position_load(tradingAccountId, fuzzMarketConfig.marketId);

        UD60x18 newPrice = ud60x18(position.lastInteractionPrice).add(ud60x18(1e18));
        SD59x18 priceShift = newPrice.intoSD59x18().sub(ud60x18(position.lastInteractionPrice).intoSD59x18());
        SD59x18 expectedUnrealizedPnl = sd59x18(position.size).mul(priceShift);

        SD59x18 unrealizedPnl =
            perpsEngine.exposed_getUnrealizedPnl(tradingAccountId, fuzzMarketConfig.marketId, newPrice);

        // it should return the unrealized pnl usd
        assertEq(
            expectedUnrealizedPnl.intoInt256(), unrealizedPnl.intoInt256(), "expected unrealidzed pnl is not correct"
        );
    }
}
