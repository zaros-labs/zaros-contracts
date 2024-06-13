// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Test } from "test/Base.t.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";

contract CancelMarketOrder_Integration_Test is Base_Test {
    function setUp() public override {
        Base_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_RevertGiven_TheSenderIsNotTheTradingAccountOwner(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
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

        changePrank({ msgSender: users.owner });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountPermissionDenied.selector, tradingAccountId, users.owner)
        });

        perpsEngine.cancelMarketOrder(tradingAccountId);
    }

    modifier givenTheSenderIsTheTradingAccountOwner() {
        _;
    }

    function test_RevertGiven_TheresNoMarketOrder(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        uint256 marketId
    )
        external
        givenTheSenderIsTheTradingAccountOwner
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoActiveMarketOrder.selector, tradingAccountId) });

        perpsEngine.cancelMarketOrder(tradingAccountId);
    }

    function test_GivenTheresAMarketOrder(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheSenderIsTheTradingAccountOwner
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxSkew: ud60x18(fuzzMarketConfig.maxSkew),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            OrderBranch.CreateMarketOrderParams({
                tradingAccountId: tradingAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        // it should emit {LogCancelMarketOrder} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit OrderBranch.LogCancelMarketOrder(users.naruto, tradingAccountId);

        perpsEngine.cancelMarketOrder(tradingAccountId);

        MarketOrder.Data memory marketOrder = perpsEngine.getActiveMarketOrder(tradingAccountId);

        // it should cancel the active market order
        assertEq(marketOrder.marketId, 0);
        assertEq(marketOrder.sizeDelta, 0);
        assertEq(marketOrder.timestamp, 0);
    }
}
