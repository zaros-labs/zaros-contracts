// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract Position_GetState_Unit_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
    }

    function testFuzz_WhenGetStateIsCalled(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId,
        bool isLong
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

        UD60x18 priceX18 = ud60x18(fuzzMarketConfig.mockUsdPrice);
        UD60x18 initialMarginRateX18 = ud60x18(fuzzMarketConfig.imr);
        UD60x18 maintenanceMarginRateX18 = ud60x18(fuzzMarketConfig.mmr);
        SD59x18 fundingFeePerUnitX18 = sd59x18(1e18);

        Position.State memory state = perpsEngine.exposed_getState(
            tradingAccountId,
            fuzzMarketConfig.marketId,
            initialMarginRateX18,
            maintenanceMarginRateX18,
            priceX18,
            fundingFeePerUnitX18
        );

        // it should return the size
        assertEq(position.size, state.sizeX18.intoInt256(), "Invalid size");

        // it should return the notional value
        UD60x18 expectedNotionalValue = sd59x18(position.size).abs().intoUD60x18().mul(priceX18);
        assertEq(expectedNotionalValue.intoUint256(), state.notionalValueX18.intoUint256(), "Invalid notional value");

        // it should return the initial margin usd
        UD60x18 expectedInitialMarginUsdX18 = expectedNotionalValue.mul(initialMarginRateX18);
        assertEq(
            expectedInitialMarginUsdX18.intoUint256(),
            state.initialMarginUsdX18.intoUint256(),
            "Invalid initial margin usd"
        );

        // it should return the maintenance margin usd
        UD60x18 expectedMaintenanceMarginUsdX18 = expectedNotionalValue.mul(maintenanceMarginRateX18);
        assertEq(
            expectedMaintenanceMarginUsdX18.intoUint256(),
            state.maintenanceMarginUsdX18.intoUint256(),
            "Invalid maintenance margin usd"
        );

        // it should return the entry price
        assertEq(position.lastInteractionPrice, state.entryPriceX18.intoUint256(), "Invalid entry price");

        // it should return the accrued funding usd
        SD59x18 netFundingFeePerUnit = fundingFeePerUnitX18.sub(sd59x18(position.lastInteractionFundingFeePerUnit));
        SD59x18 expectedAccruedFundingUsdX18 = sd59x18(position.size).mul(netFundingFeePerUnit);
        assertEq(
            expectedAccruedFundingUsdX18.intoInt256(),
            state.accruedFundingUsdX18.intoInt256(),
            "Invalid accrued funding usd"
        );

        // it should return the unrealized pnl usd
        SD59x18 priceShift = priceX18.intoSD59x18().sub(ud60x18(position.lastInteractionPrice).intoSD59x18());
        SD59x18 expectedUnrealizedPnl = sd59x18(position.size).mul(priceShift);
        assertEq(
            expectedUnrealizedPnl.intoInt256(), state.unrealizedPnlUsdX18.intoInt256(), "Invalid unrealized pnl usd"
        );
    }
}
