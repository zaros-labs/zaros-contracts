// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { MarginCollateralConfiguration } from "@zaros/perpetuals/leaves/MarginCollateralConfiguration.sol";

// PRB Math dependencies
import { ud60x18, UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

contract GetAccountEquityUsd_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertGiven_TheresNotAnAccountTradingCreated(uint128 randomTradingAccountId) external {
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, randomTradingAccountId, users.naruto)
        });

        // it should revert
        perpsEngine.getAccountEquityUsd(randomTradingAccountId);
    }

    modifier givenTheresAnAccountTrading() {
        _;
    }

    function test_GivenTheresNotAPositionCreated(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheresAnAccountTrading
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: WSTETH_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        // marginValueUsd = bound({ x: marginValueUsd, min: 1, max: WSTETH_DEPOSIT_CAP });
        deal({ token: address(mockWstEth), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        perpsEngine.depositMargin(tradingAccountId, address(mockWstEth), marginValueUsd);

        UD60x18 marginCollateralValue = getPrice(mockPriceAdapters.mockUsdcUsdPriceAdapter).mul(
            ud60x18(marginValueUsd)
        ).add(getPrice(mockPriceAdapters.mockWstEthUsdPriceAdapter).mul(ud60x18(marginValueUsd)));

        // it should return the account equity usd
        SD59x18 equityUsd = perpsEngine.getAccountEquityUsd(tradingAccountId);
        assertEq(
            marginCollateralValue.intoUint256(), equityUsd.intoUint256(), "Account equity usd is not the expected"
        );
    }

    function test_GivenTheresAPositionCreated(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheresAnAccountTrading
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });

        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: WSTETH_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        // marginValueUsd = bound({ x: marginValueUsd, min: 1, max: WSTETH_DEPOSIT_CAP });
        deal({ token: address(mockWstEth), to: users.naruto, give: marginValueUsd });

        uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        perpsEngine.depositMargin(tradingAccountId, address(mockWstEth), marginValueUsd);

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

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);

        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        changePrank({ msgSender: marketOrderKeeper });
        perpsEngine.fillMarketOrder(tradingAccountId, fuzzMarketConfig.marketId, feeRecipients, mockSignedReport);

        SD59x18 accountTotalUnrealizedPnl = perpsEngine.getAccountTotalUnrealizedPnl(tradingAccountId);

        UD60x18 marginCollateralValue = getPrice(mockPriceAdapters.mockUsdcUsdPriceAdapter).mul(
            ud60x18(marginValueUsd)
        ).add(getPrice(mockPriceAdapters.mockWstEthUsdPriceAdapter).mul(ud60x18(marginValueUsd)));

        // it should return the account equity usd
        SD59x18 equityUsd = perpsEngine.getAccountEquityUsd(tradingAccountId);

        SD59x18 expectedEquityUsd = marginCollateralValue.intoSD59x18().add(accountTotalUnrealizedPnl);

        assertAlmostEq(
            expectedEquityUsd.intoUint256(), equityUsd.intoUint256(), 6e23, "Account equity usd is not the expected"
        );
    }
}
