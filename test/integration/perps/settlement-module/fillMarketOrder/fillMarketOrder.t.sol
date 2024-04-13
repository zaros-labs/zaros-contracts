// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { IOrderModule } from "@zaros/markets/perps/interfaces/IOrderModule.sol";
import { MarketOrder } from "@zaros/markets/perps/storage/MarketOrder.sol";
import { Position } from "@zaros/markets/perps/storage/Position.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract FillMarketOrder_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheKeeper(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketIndex
    )
        external
    {
        (MarketConfig memory fuzzMarketConfig) = getFuzzMarketConfig(marketIndex);

        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.OnlyKeeper.selector, users.naruto, marketOrderKeepers[fuzzMarketConfig.marketId]
                )
        });
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, marketOrderKeeper, mockSignedReport);
    }

    modifier givenTheSenderIsTheKeeper() {
        _;
    }

    function testFuzz_RevertGiven_TheMarketOrderDoesNotExist(
        uint256 marginValueUsd,
        uint256 marketIndex
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
    {
        (MarketConfig memory fuzzMarketConfig) = getFuzzMarketConfig(marketIndex);
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        changePrank({ msgSender: marketOrderKeeper });
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoActiveMarketOrder.selector, perpsAccountId) });
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, marketOrderKeeper, mockSignedReport);
    }

    modifier givenTheMarketOrderExists() {
        _;
    }

    function testFuzz_RevertGiven_ThePerpMarketIsDisabled(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketIndex
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
    {
        (MarketConfig memory fuzzMarketConfig) = getFuzzMarketConfig(marketIndex);
        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketStatus({ marketId: fuzzMarketConfig.marketId, enable: false });

        changePrank({ msgSender: marketOrderKeeper });
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.PerpMarketDisabled.selector, fuzzMarketConfig.marketId)
        });
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, marketOrderKeeper, mockSignedReport);
    }

    modifier givenThePerpMarketIsEnabled() {
        _;
    }

    function test_RevertWhen_TheSizeDeltaIsBelowTheMinimum()
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
    {
        // it should revert
    }

    modifier whenTheSizeDeltaIsAboveTheMinimum() {
        _;
    }

    function test_RevertGiven_TheSettlementStrategyIsDisabled()
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsAboveTheMinimum
    {
        // it should revert
    }

    modifier givenTheSettlementStrategyIsEnabled() {
        _;
    }

    function test_RevertGiven_TheSettlementStrategyDoesNotExist()
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsAboveTheMinimum
        givenTheSettlementStrategyIsEnabled
    {
        // it should revert
    }

    modifier givenTheSettlementStrategyExists() {
        _;
    }

    function test_RevertGiven_TheReportVerificationFails()
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsAboveTheMinimum
        givenTheSettlementStrategyIsEnabled
        givenTheSettlementStrategyExists
    {
        // it should revert
    }

    modifier givenTheReportVerificationPasses() {
        _;
    }

    function test_RevertGiven_TheDataStreamsReportIsInvalid()
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsAboveTheMinimum
        givenTheSettlementStrategyIsEnabled
        givenTheSettlementStrategyExists
        givenTheReportVerificationPasses
    {
        // it should revert
    }

    modifier givenTheDataStreamsReportIsValid() {
        _;
    }

    function test_RevertGiven_TheAccountWontMeetTheMarginRequirement()
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsAboveTheMinimum
        givenTheSettlementStrategyIsEnabled
        givenTheSettlementStrategyExists
        givenTheReportVerificationPasses
        givenTheDataStreamsReportIsValid
    {
        // it should revert
    }

    modifier givenTheAccountWillMeetTheMarginRequirement() {
        _;
    }

    function test_RevertGiven_TheMarketsOILimitWillBeExceeded()
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsAboveTheMinimum
        givenTheSettlementStrategyIsEnabled
        givenTheSettlementStrategyExists
        givenTheReportVerificationPasses
        givenTheDataStreamsReportIsValid
        givenTheAccountWillMeetTheMarginRequirement
    {
        // it should revert
    }

    function test_GivenTheMarketsOILimitWontBeExceeded()
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsAboveTheMinimum
        givenTheSettlementStrategyIsEnabled
        givenTheSettlementStrategyExists
        givenTheReportVerificationPasses
        givenTheDataStreamsReportIsValid
        givenTheAccountWillMeetTheMarginRequirement
    {
        // it should update the funding values
        // it should update the open interest and skew
        // it should update the account's active markets
        // it should update the account's position
        // it should apply the accrued pnl
        // it should emit a {LogSettleOrder} event
    }
}
