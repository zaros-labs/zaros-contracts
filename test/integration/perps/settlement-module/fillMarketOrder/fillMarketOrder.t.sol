// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { PremiumReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IOrderBranch } from "@zaros/perpetuals/interfaces/IOrderBranch.sol";
import { ISettlementBranch } from "@zaros/perpetuals/interfaces/ISettlementBranch.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

import { console } from "forge-std/console.sol";

contract FillMarketOrder_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();
        createPerpMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertGiven_TheSenderIsNotTheKeeper(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        FuzzMarginPortfolio memory fuzzMarginPortfolio =
            getFuzzMarginPortfolio(fuzzMarketConfig, initialMarginRate, marginValueUsd);

        uint128 perpsAccountId = createAccountAndDeposit(fuzzMarginPortfolio.marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(fuzzMarginPortfolio.initialMarginRate),
                marginValueUsd: ud60x18(fuzzMarginPortfolio.marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
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
            revertData: abi.encodeWithSelector(Errors.OnlyKeeper.selector, users.naruto, marketOrderKeeper)
        });
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, feeRecipients, mockSignedReport);
    }

    modifier givenTheSenderIsTheKeeper() {
        _;
    }

    function testFuzz_RevertGiven_TheMarketOrderDoesNotExist(
        uint256 marginValueUsd,
        uint256 marketId
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        FuzzMarginPortfolio memory fuzzMarginPortfolio = getFuzzMarginPortfolio(fuzzMarketConfig, 0, marginValueUsd);

        uint128 perpsAccountId = createAccountAndDeposit(fuzzMarginPortfolio.marginValueUsd, address(usdToken));

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        changePrank({ msgSender: marketOrderKeeper });
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.NoActiveMarketOrder.selector, perpsAccountId) });
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, feeRecipients, mockSignedReport);
    }

    modifier givenTheMarketOrderExists() {
        _;
    }

    function testFuzz_RevertGiven_ThePerpMarketIsDisabled(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        FuzzMarginPortfolio memory fuzzMarginPortfolio =
            getFuzzMarginPortfolio(fuzzMarketConfig, initialMarginRate, marginValueUsd);

        uint128 perpsAccountId = createAccountAndDeposit(fuzzMarginPortfolio.marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(fuzzMarginPortfolio.initialMarginRate),
                marginValueUsd: ud60x18(fuzzMarginPortfolio.marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
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
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, feeRecipients, mockSignedReport);
    }

    modifier givenThePerpMarketIsEnabled() {
        _;
    }

    function testFuzz_RevertGiven_TheSettlementStrategyIsDisabled(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        givenTheSettlementStrategyIsEnabled
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        FuzzMarginPortfolio memory fuzzMarginPortfolio =
            getFuzzMarginPortfolio(fuzzMarketConfig, initialMarginRate, marginValueUsd);

        uint128 perpsAccountId = createAccountAndDeposit(fuzzMarginPortfolio.marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(fuzzMarginPortfolio.initialMarginRate),
                marginValueUsd: ud60x18(fuzzMarginPortfolio.marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
            .DataStreamsStrategy({
            chainlinkVerifier: IVerifierProxy(mockChainlinkVerifier),
            streamId: fuzzMarketConfig.streamId
        });
        SettlementConfiguration.Data memory marketOrderConfiguration = SettlementConfiguration.Data({
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_ONCHAIN,
            isEnabled: false,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: marketOrderKeepers[fuzzMarketConfig.marketId],
            data: abi.encode(marketOrderConfigurationData)
        });

        changePrank({ msgSender: users.owner });

        perpsEngine.updateSettlementConfiguration({
            marketId: fuzzMarketConfig.marketId,
            settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            newSettlementConfiguration: marketOrderConfiguration
        });

        changePrank({ msgSender: marketOrderKeeper });
        // it should revert
        vm.expectRevert({ revertData: Errors.SettlementDisabled.selector });
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, feeRecipients, mockSignedReport);
    }

    modifier givenTheSettlementStrategyIsEnabled() {
        _;
    }

    function testFuzz_RevertGiven_TheReportVerificationFails(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        givenTheSettlementStrategyIsEnabled
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        FuzzMarginPortfolio memory fuzzMarginPortfolio =
            getFuzzMarginPortfolio(fuzzMarketConfig, initialMarginRate, marginValueUsd);

        uint128 perpsAccountId = createAccountAndDeposit(fuzzMarginPortfolio.marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(fuzzMarginPortfolio.initialMarginRate),
                marginValueUsd: ud60x18(fuzzMarginPortfolio.marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        SettlementConfiguration.DataStreamsStrategy memory marketOrderConfigurationData = SettlementConfiguration
            .DataStreamsStrategy({ chainlinkVerifier: IVerifierProxy(address(1)), streamId: fuzzMarketConfig.streamId });
        SettlementConfiguration.Data memory marketOrderConfiguration = SettlementConfiguration.Data({
            strategy: SettlementConfiguration.Strategy.DATA_STREAMS_ONCHAIN,
            isEnabled: true,
            fee: DEFAULT_SETTLEMENT_FEE,
            keeper: marketOrderKeepers[fuzzMarketConfig.marketId],
            data: abi.encode(marketOrderConfigurationData)
        });

        changePrank({ msgSender: users.owner });

        perpsEngine.updateSettlementConfiguration({
            marketId: fuzzMarketConfig.marketId,
            settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            newSettlementConfiguration: marketOrderConfiguration
        });

        changePrank({ msgSender: marketOrderKeeper });
        // it should revert
        vm.expectRevert();
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, feeRecipients, mockSignedReport);
    }

    modifier givenTheReportVerificationPasses() {
        _;
    }

    function testFuzz_RevertGiven_TheDataStreamsReportIsInvalid(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        givenTheSettlementStrategyIsEnabled
        givenTheReportVerificationPasses
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        FuzzMarginPortfolio memory fuzzMarginPortfolio =
            getFuzzMarginPortfolio(fuzzMarketConfig, initialMarginRate, marginValueUsd);

        uint256 wrongMarketId = fuzzMarketConfig.marketId < FINAL_MARKET_ID
            ? fuzzMarketConfig.marketId + 1
            : fuzzMarketConfig.marketId - 1;

        uint256[2] memory marketsIdsRange;
        marketsIdsRange[0] = wrongMarketId;
        marketsIdsRange[1] = wrongMarketId;

        MarketConfig memory wrongMarketConfig = getFilteredMarketsConfig(marketsIdsRange)[0];

        uint128 perpsAccountId = createAccountAndDeposit(fuzzMarginPortfolio.marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(fuzzMarginPortfolio.initialMarginRate),
                marginValueUsd: ud60x18(fuzzMarginPortfolio.marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        bytes memory mockSignedReport =
            getMockedSignedReport(wrongMarketConfig.streamId, wrongMarketConfig.mockUsdPrice);
        (, bytes memory mockReportData) = abi.decode(mockSignedReport, (bytes32[3], bytes));
        PremiumReport memory premiumReport = abi.decode(mockReportData, (PremiumReport));

        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        changePrank({ msgSender: marketOrderKeeper });
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InvalidDataStreamReport.selector, fuzzMarketConfig.streamId, premiumReport.feedId
            )
        });
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, feeRecipients, mockSignedReport);
    }

    modifier givenTheDataStreamsReportIsValid() {
        _;
    }

    function testFuzz_RevertGiven_TheAccountWontMeetTheMarginRequirement(
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        givenTheSettlementStrategyIsEnabled
        givenTheReportVerificationPasses
        givenTheDataStreamsReportIsValid
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // avoids very small rounding errors in super edge cases
        UD60x18 adjustedMarginRequirements = ud60x18(fuzzMarketConfig.marginRequirements).mul(ud60x18(1.001e18));
        UD60x18 maxMarginValueUsd = adjustedMarginRequirements.mul(ud60x18(fuzzMarketConfig.maxOi)).mul(
            ud60x18(fuzzMarketConfig.mockUsdPrice)
        );

        marginValueUsd =
            bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: maxMarginValueUsd.intoUint256() });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: adjustedMarginRequirements,
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        UD60x18 newMarginRequirements = ud60x18(fuzzMarketConfig.marginRequirements).mul(ud60x18(1.1e18));

        changePrank({ msgSender: users.owner });
        updatePerpMarketMarginRequirements(
            fuzzMarketConfig.marketId,
            newMarginRequirements.div(ud60x18(2e18)),
            newMarginRequirements.div(ud60x18(2e18))
        );

        (
            SD59x18 marginBalanceUsdX18,
            UD60x18 requiredInitialMarginUsdX18,
            UD60x18 requiredMaintenanceMarginUsdX18,
            SD59x18 orderFeeUsdX18,
            UD60x18 settlementFeeUsdX18,
        ) = perpsEngine.simulateTrade(
            perpsAccountId,
            fuzzMarketConfig.marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            sizeDelta
        );

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);

        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        changePrank({ msgSender: marketOrderKeeper });
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.InsufficientMargin.selector,
                perpsAccountId,
                marginBalanceUsdX18.intoInt256(),
                requiredInitialMarginUsdX18.add(requiredMaintenanceMarginUsdX18).intoUint256(),
                orderFeeUsdX18.add(settlementFeeUsdX18.intoSD59x18()).intoInt256()
            )
        });
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, feeRecipients, mockSignedReport);
    }

    modifier givenTheAccountWillMeetTheMarginRequirement() {
        _;
    }

    function testFuzz_RevertGiven_TheMarketsOILimitWillBeExceeded(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        givenTheSettlementStrategyIsEnabled
        givenTheReportVerificationPasses
        givenTheDataStreamsReportIsValid
        givenTheAccountWillMeetTheMarginRequirement
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);
        FuzzMarginPortfolio memory fuzzMarginPortfolio =
            getFuzzMarginPortfolio(fuzzMarketConfig, initialMarginRate, marginValueUsd);

        uint128 perpsAccountId = createAccountAndDeposit(fuzzMarginPortfolio.marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(fuzzMarginPortfolio.initialMarginRate),
                marginValueUsd: ud60x18(fuzzMarginPortfolio.marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta
            })
        );

        changePrank({ msgSender: users.owner });
        UD60x18 sizeDeltaAbs = sd59x18(sizeDelta).abs().intoUD60x18();
        UD60x18 newMaxOi = sizeDeltaAbs.sub(ud60x18(1));
        updatePerpMarketMaxOi(fuzzMarketConfig.marketId, newMaxOi);

        bytes memory mockSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice);
        address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];

        changePrank({ msgSender: marketOrderKeeper });
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.ExceedsOpenInterestLimit.selector, fuzzMarketConfig.marketId, newMaxOi, sizeDeltaAbs
            )
        });
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, feeRecipients, mockSignedReport);
    }

    modifier givenTheMarketsOILimitWontBeExceeded() {
        _;
    }

    struct TestFuzz_GivenThePnlIsNegative_Context {
        MarketConfig fuzzMarketConfig;
        uint256 adjustedMarginRequirements;
        uint256 priceShiftBps;
        address marketOrderKeeper;
        uint128 perpsAccountId;
        int128 firstOrderSizeDelta;
        SD59x18 firstOrderFeeUsdX18;
        UD60x18 firstFillPriceX18;
        int256 firstOrderExpectedPnl;
        bytes firstMockSignedReport;
        uint256 expectedOpenInterest;
        UD60x18 openInterestX18;
        int256 expectedSkew;
        SD59x18 skewX18;
        uint256 expectedActiveMarketId;
        Position.Data expectedPosition;
        int256 expectedMarginBalanceUsd;
        SD59x18 marginBalanceUsdX18;
        uint256 newIndexPrice;
        int128 secondOrderSizeDelta;
        SD59x18 secondOrderFeeUsdX18;
        UD60x18 secondFillPriceX18;
        SD59x18 secondOrderExpectedPriceShiftPnlX18;
        int256 secondOrderExpectedPnl;
        bytes secondMockSignedReport;
    }

    // TODO: add funding assertions
    function testFuzz_GivenThePnlIsNegative(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId,
        uint256 priceShiftRatio
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        givenTheSettlementStrategyIsEnabled
        givenTheReportVerificationPasses
        givenTheDataStreamsReportIsValid
        givenTheAccountWillMeetTheMarginRequirement
        givenTheMarketsOILimitWontBeExceeded
    {
        TestFuzz_GivenThePnlIsNegative_Context memory ctx;
        ctx.fuzzMarketConfig = getFuzzMarketConfig(marketId);
        FuzzMarginPortfolio memory fuzzMarginPortfolio =
            getFuzzMarginPortfolio(ctx.fuzzMarketConfig, initialMarginRate, marginValueUsd);

        ctx.adjustedMarginRequirements =
            ud60x18(ctx.fuzzMarketConfig.marginRequirements).mul(ud60x18(1.1e18)).intoUint256();

        priceShiftRatio = bound({ x: priceShiftRatio, min: 2, max: 100 });
        initialMarginRate =
            bound({ x: initialMarginRate, min: ctx.adjustedMarginRequirements, max: MAX_MARGIN_REQUIREMENTS });

        ctx.priceShiftBps = ctx.adjustedMarginRequirements / priceShiftRatio;
        ctx.marketOrderKeeper = marketOrderKeepers[ctx.fuzzMarketConfig.marketId];

        ctx.perpsAccountId = createAccountAndDeposit(fuzzMarginPortfolio.marginValueUsd, address(usdToken));

        ctx.firstOrderSizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: ctx.perpsAccountId,
                marketId: ctx.fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(fuzzMarginPortfolio.initialMarginRate),
                marginValueUsd: ud60x18(fuzzMarginPortfolio.marginValueUsd),
                maxOpenInterest: ud60x18(ctx.fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(ctx.fuzzMarketConfig.minTradeSize),
                price: ud60x18(ctx.fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        (,,, ctx.firstOrderFeeUsdX18,,) = perpsEngine.simulateTrade(
            ctx.perpsAccountId,
            ctx.fuzzMarketConfig.marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            ctx.firstOrderSizeDelta
        );

        ctx.firstFillPriceX18 = perpsEngine.getMarkPrice(
            ctx.fuzzMarketConfig.marketId, ctx.fuzzMarketConfig.mockUsdPrice, ctx.firstOrderSizeDelta
        );

        // first market order
        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
                accountId: ctx.perpsAccountId,
                marketId: ctx.fuzzMarketConfig.marketId,
                sizeDelta: ctx.firstOrderSizeDelta
            })
        );

        ctx.firstMockSignedReport =
            getMockedSignedReport(ctx.fuzzMarketConfig.streamId, ctx.fuzzMarketConfig.mockUsdPrice);

        ctx.firstOrderExpectedPnl =
            unary(ctx.firstOrderFeeUsdX18.add(ud60x18(DEFAULT_SETTLEMENT_FEE).intoSD59x18())).intoInt256();

        changePrank({ msgSender: ctx.marketOrderKeeper });

        // it should emit a {LogSettleOrder} event
        // it should transfer the pnl and fees
        vm.expectEmit({ emitter: address(perpsEngine) });
        expectCallToTransfer(usdToken, feeRecipients.settlementFeeRecipient, DEFAULT_SETTLEMENT_FEE);
        expectCallToTransfer(
            usdToken, feeRecipients.orderFeeRecipient, ctx.firstOrderFeeUsdX18.intoUD60x18().intoUint256()
        );
        emit ISettlementBranch.LogSettleOrder({
            sender: ctx.marketOrderKeeper,
            accountId: ctx.perpsAccountId,
            marketId: ctx.fuzzMarketConfig.marketId,
            sizeDelta: ctx.firstOrderSizeDelta,
            fillPrice: ctx.firstFillPriceX18.intoUint256(),
            orderFeeUsd: ctx.firstOrderFeeUsdX18.intoInt256(),
            settlementFeeUsd: DEFAULT_SETTLEMENT_FEE,
            pnl: ctx.firstOrderExpectedPnl,
            fundingFeePerUnit: 0
        });

        // fill first order and open position
        perpsEngine.fillMarketOrder(
            ctx.perpsAccountId, ctx.fuzzMarketConfig.marketId, feeRecipients, ctx.firstMockSignedReport
        );
        // TODO: assert after funding task is done
        // it should update the funding values

        // it should update the open interest and skew
        ctx.expectedOpenInterest = sd59x18(ctx.firstOrderSizeDelta).abs().intoUD60x18().intoUint256();
        ctx.expectedSkew = ctx.firstOrderSizeDelta;
        (,, ctx.openInterestX18) = perpsEngine.getOpenInterest(ctx.fuzzMarketConfig.marketId);
        ctx.skewX18 = perpsEngine.getSkew(ctx.fuzzMarketConfig.marketId);
        assertAlmostEq(ctx.expectedOpenInterest, ctx.openInterestX18.intoUint256(), 1, "first fill: open interest");
        assertEq(ctx.expectedSkew, ctx.skewX18.intoInt256(), "first fill: skew");

        // TODO: assert after harnesses are done
        // it should update the account's active markets
        ctx.expectedActiveMarketId = ctx.fuzzMarketConfig.marketId;

        // TODO: assert after harnesses are done
        // it should update the account's position
        ctx.expectedPosition = Position.Data({
            size: ctx.firstOrderSizeDelta,
            lastInteractionPrice: ctx.firstFillPriceX18.intoUint128(),
            lastInteractionFundingFeePerUnit: 0
        });

        // it should deduct the pnl and fees
        ctx.expectedMarginBalanceUsd = int256(fuzzMarginPortfolio.marginValueUsd) + ctx.firstOrderExpectedPnl;
        (ctx.marginBalanceUsdX18,,,) = perpsEngine.getAccountMarginBreakdown(ctx.perpsAccountId);
        console.log("returned margin bal: ");
        console.log(ctx.marginBalanceUsdX18.intoUD60x18().intoUint256());
        assertEq(ctx.expectedMarginBalanceUsd, ctx.marginBalanceUsdX18.intoInt256(), "first fill: margin balance");

        changePrank({ msgSender: users.naruto });

        ctx.newIndexPrice = isLong
            ? ud60x18(ctx.fuzzMarketConfig.mockUsdPrice).mul(ud60x18(1e18).sub(ud60x18(ctx.priceShiftBps))).intoUint256()
            : ud60x18(ctx.fuzzMarketConfig.mockUsdPrice).mul(ud60x18(1e18).add(ud60x18(ctx.priceShiftBps))).intoUint256();
        updateMockPriceFeed(ctx.fuzzMarketConfig.marketId, ctx.newIndexPrice);

        ctx.secondOrderSizeDelta = -ctx.firstOrderSizeDelta;

        (,,, ctx.secondOrderFeeUsdX18,,) = perpsEngine.simulateTrade(
            ctx.perpsAccountId,
            ctx.fuzzMarketConfig.marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            ctx.secondOrderSizeDelta
        );

        ctx.secondFillPriceX18 =
            perpsEngine.getMarkPrice(ctx.fuzzMarketConfig.marketId, ctx.newIndexPrice, ctx.secondOrderSizeDelta);

        // second market order
        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
                accountId: ctx.perpsAccountId,
                marketId: ctx.fuzzMarketConfig.marketId,
                sizeDelta: ctx.secondOrderSizeDelta
            })
        );

        ctx.secondMockSignedReport = getMockedSignedReport(ctx.fuzzMarketConfig.streamId, ctx.newIndexPrice);

        // ctx.secondOrderExpectedPriceShiftPnlX18 = ctx.secondFillPriceX18.intoSD59x18().sub(
        //     ctx.firstFillPriceX18.intoSD59x18()
        // ).mul(sd59x18(ctx.firstOrderSizeDelta));
        ctx.secondOrderExpectedPriceShiftPnlX18 = ctx.secondFillPriceX18.intoSD59x18().sub(
            ctx.firstFillPriceX18.intoSD59x18()
        ).mul(sd59x18(ctx.firstOrderSizeDelta));
        ctx.secondOrderExpectedPnl = unary(
            ctx.secondOrderFeeUsdX18.add(ud60x18(DEFAULT_SETTLEMENT_FEE).intoSD59x18())
        ).add(ctx.secondOrderExpectedPriceShiftPnlX18).intoInt256();

        changePrank({ msgSender: ctx.marketOrderKeeper });

        // it should emit a {LogSettleOrder} event
        // it should transfer the pnl and fees
        vm.expectEmit({ emitter: address(perpsEngine) });
        expectCallToTransfer(usdToken, feeRecipients.settlementFeeRecipient, DEFAULT_SETTLEMENT_FEE);
        expectCallToTransfer(
            usdToken, feeRecipients.orderFeeRecipient, ctx.secondOrderFeeUsdX18.intoUD60x18().intoUint256()
        );
        expectCallToTransfer(
            usdToken,
            feeRecipients.marginCollateralRecipient,
            ctx.secondOrderExpectedPriceShiftPnlX18.abs().intoUD60x18().intoUint256()
        );
        emit ISettlementBranch.LogSettleOrder({
            sender: ctx.marketOrderKeeper,
            accountId: ctx.perpsAccountId,
            marketId: ctx.fuzzMarketConfig.marketId,
            sizeDelta: ctx.secondOrderSizeDelta,
            fillPrice: ctx.secondFillPriceX18.intoUint256(),
            orderFeeUsd: ctx.secondOrderFeeUsdX18.intoInt256(),
            settlementFeeUsd: DEFAULT_SETTLEMENT_FEE,
            pnl: ctx.secondOrderExpectedPnl,
            fundingFeePerUnit: 0
        });
        // fill second order and close position
        perpsEngine.fillMarketOrder(
            ctx.perpsAccountId, ctx.fuzzMarketConfig.marketId, feeRecipients, ctx.secondMockSignedReport
        );

        // TODO: assert after funding task is done
        // it should update the funding values

        // it should update the open interest and skew
        ctx.expectedOpenInterest = 0;
        ctx.expectedSkew = 0;
        (,, ctx.openInterestX18) = perpsEngine.getOpenInterest(ctx.fuzzMarketConfig.marketId);
        ctx.skewX18 = perpsEngine.getSkew(ctx.fuzzMarketConfig.marketId);
        assertAlmostEq(ctx.expectedOpenInterest, ctx.openInterestX18.intoUint256(), 1, "first fill: open interest");
        assertEq(ctx.expectedSkew, ctx.skewX18.intoInt256(), "first fill: skew");

        // TODO: assert after harnesses are done
        // it should update the account's active markets
        ctx.expectedActiveMarketId = ctx.fuzzMarketConfig.marketId;

        // TODO: assert after harnesses are done
        // it should update the account's position
        ctx.expectedPosition =
            Position.Data({ size: 0, lastInteractionPrice: 0, lastInteractionFundingFeePerUnit: 0 });

        // it should deduct the pnl and fees
        ctx.expectedMarginBalanceUsd =
            int256(fuzzMarginPortfolio.marginValueUsd) + ctx.firstOrderExpectedPnl + ctx.secondOrderExpectedPnl;
        (ctx.marginBalanceUsdX18,,,) = perpsEngine.getAccountMarginBreakdown(ctx.perpsAccountId);
        console.log("returned margin bal: ");
        console.log(ctx.marginBalanceUsdX18.intoUD60x18().intoUint256());
        assertEq(ctx.expectedMarginBalanceUsd, ctx.marginBalanceUsdX18.intoInt256(), "first fill: margin balance");
    }

    struct TestFuzz_GivenThePnlIsPositive_Context {
        MarketConfig fuzzMarketConfig;
        uint256 adjustedMarginRequirements;
        uint256 priceShiftBps;
        address marketOrderKeeper;
        uint128 perpsAccountId;
        int128 firstOrderSizeDelta;
        SD59x18 firstOrderFeeUsdX18;
        UD60x18 firstFillPriceX18;
        int256 firstOrderExpectedPnl;
        bytes firstMockSignedReport;
        uint256 expectedOpenInterest;
        UD60x18 openInterestX18;
        int256 expectedSkew;
        SD59x18 skewX18;
        uint256 expectedActiveMarketId;
        Position.Data expectedPosition;
        int256 expectedMarginBalanceUsd;
        SD59x18 marginBalanceUsdX18;
        uint256 newIndexPrice;
        int128 secondOrderSizeDelta;
        SD59x18 secondOrderFeeUsdX18;
        UD60x18 secondFillPriceX18;
        SD59x18 secondOrderExpectedPriceShiftPnlX18;
        int256 secondOrderExpectedPnl;
        bytes secondMockSignedReport;
    }

    function testFuzz_GivenThePnlIsPositive(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId,
        uint256 priceShift
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        givenTheSettlementStrategyIsEnabled
        givenTheSettlementStrategyIsEnabled
        givenTheReportVerificationPasses
        givenTheDataStreamsReportIsValid
        givenTheAccountWillMeetTheMarginRequirement
        givenTheMarketsOILimitWontBeExceeded
    {
        TestFuzz_GivenThePnlIsPositive_Context memory ctx;
        ctx.fuzzMarketConfig = getFuzzMarketConfig(marketId);
        FuzzMarginPortfolio memory fuzzMarginPortfolio =
            getFuzzMarginPortfolio(ctx.fuzzMarketConfig, initialMarginRate, marginValueUsd);

        ctx.adjustedMarginRequirements =
            ud60x18(ctx.fuzzMarketConfig.marginRequirements).mul(ud60x18(1.1e18)).intoUint256();

        priceShift = bound({ x: priceShift, min: 1.1e18, max: 10e18 });
        initialMarginRate =
            bound({ x: initialMarginRate, min: ctx.adjustedMarginRequirements, max: MAX_MARGIN_REQUIREMENTS });

        ctx.marketOrderKeeper = marketOrderKeepers[ctx.fuzzMarketConfig.marketId];

        ctx.perpsAccountId = createAccountAndDeposit(fuzzMarginPortfolio.marginValueUsd, address(usdToken));

        ctx.firstOrderSizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: ctx.perpsAccountId,
                marketId: ctx.fuzzMarketConfig.marketId,
                settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(fuzzMarginPortfolio.initialMarginRate),
                marginValueUsd: ud60x18(fuzzMarginPortfolio.marginValueUsd),
                maxOpenInterest: ud60x18(ctx.fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(ctx.fuzzMarketConfig.minTradeSize),
                price: ud60x18(ctx.fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        (,,, ctx.firstOrderFeeUsdX18,,) = perpsEngine.simulateTrade(
            ctx.perpsAccountId,
            ctx.fuzzMarketConfig.marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            ctx.firstOrderSizeDelta
        );

        ctx.firstFillPriceX18 = perpsEngine.getMarkPrice(
            ctx.fuzzMarketConfig.marketId, ctx.fuzzMarketConfig.mockUsdPrice, ctx.firstOrderSizeDelta
        );

        // first market order
        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
                accountId: ctx.perpsAccountId,
                marketId: ctx.fuzzMarketConfig.marketId,
                sizeDelta: ctx.firstOrderSizeDelta
            })
        );

        ctx.firstMockSignedReport =
            getMockedSignedReport(ctx.fuzzMarketConfig.streamId, ctx.fuzzMarketConfig.mockUsdPrice);

        ctx.firstOrderExpectedPnl =
            unary(ctx.firstOrderFeeUsdX18.add(ud60x18(DEFAULT_SETTLEMENT_FEE).intoSD59x18())).intoInt256();

        changePrank({ msgSender: ctx.marketOrderKeeper });

        // it should emit a {LogSettleOrder} event
        // it should transfer the pnl and fees
        vm.expectEmit({ emitter: address(perpsEngine) });
        expectCallToTransfer(usdToken, feeRecipients.settlementFeeRecipient, DEFAULT_SETTLEMENT_FEE);
        expectCallToTransfer(
            usdToken, feeRecipients.orderFeeRecipient, ctx.firstOrderFeeUsdX18.intoUD60x18().intoUint256()
        );
        emit ISettlementBranch.LogSettleOrder({
            sender: ctx.marketOrderKeeper,
            accountId: ctx.perpsAccountId,
            marketId: ctx.fuzzMarketConfig.marketId,
            sizeDelta: ctx.firstOrderSizeDelta,
            fillPrice: ctx.firstFillPriceX18.intoUint256(),
            orderFeeUsd: ctx.firstOrderFeeUsdX18.intoInt256(),
            settlementFeeUsd: DEFAULT_SETTLEMENT_FEE,
            pnl: ctx.firstOrderExpectedPnl,
            fundingFeePerUnit: 0
        });

        // fill first order and open position
        console.log("filling first order: ");
        perpsEngine.fillMarketOrder(
            ctx.perpsAccountId, ctx.fuzzMarketConfig.marketId, feeRecipients, ctx.firstMockSignedReport
        );
        // TODO: assert after funding task is done
        // it should update the funding values

        // it should update the open interest and skew
        ctx.expectedOpenInterest = sd59x18(ctx.firstOrderSizeDelta).abs().intoUD60x18().intoUint256();
        ctx.expectedSkew = ctx.firstOrderSizeDelta;
        (,, ctx.openInterestX18) = perpsEngine.getOpenInterest(ctx.fuzzMarketConfig.marketId);
        ctx.skewX18 = perpsEngine.getSkew(ctx.fuzzMarketConfig.marketId);
        assertAlmostEq(ctx.expectedOpenInterest, ctx.openInterestX18.intoUint256(), 1, "first fill: open interest");
        assertEq(ctx.expectedSkew, ctx.skewX18.intoInt256(), "first fill: skew");

        // TODO: assert after harnesses are done
        // it should update the account's active markets
        ctx.expectedActiveMarketId = ctx.fuzzMarketConfig.marketId;

        // TODO: assert after harnesses are done
        // it should update the account's position
        ctx.expectedPosition = Position.Data({
            size: ctx.firstOrderSizeDelta,
            lastInteractionPrice: ctx.firstFillPriceX18.intoUint128(),
            lastInteractionFundingFeePerUnit: 0
        });

        // it should deduct fees
        ctx.expectedMarginBalanceUsd = int256(fuzzMarginPortfolio.marginValueUsd) + ctx.firstOrderExpectedPnl;
        (ctx.marginBalanceUsdX18,,,) = perpsEngine.getAccountMarginBreakdown(ctx.perpsAccountId);
        console.log("returned margin bal: ");
        console.log(ctx.marginBalanceUsdX18.intoUD60x18().intoUint256());
        assertEq(ctx.expectedMarginBalanceUsd, ctx.marginBalanceUsdX18.intoInt256(), "first fill: margin balance");

        changePrank({ msgSender: users.naruto });

        ctx.newIndexPrice = isLong
            ? ud60x18(ctx.fuzzMarketConfig.mockUsdPrice).mul(ud60x18(priceShift)).intoUint256()
            : ud60x18(ctx.fuzzMarketConfig.mockUsdPrice).div(ud60x18(priceShift)).intoUint256();
        updateMockPriceFeed(ctx.fuzzMarketConfig.marketId, ctx.newIndexPrice);

        ctx.secondOrderSizeDelta = -ctx.firstOrderSizeDelta;

        (,,, ctx.secondOrderFeeUsdX18,,) = perpsEngine.simulateTrade(
            ctx.perpsAccountId,
            ctx.fuzzMarketConfig.marketId,
            SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
            ctx.secondOrderSizeDelta
        );

        ctx.secondFillPriceX18 =
            perpsEngine.getMarkPrice(ctx.fuzzMarketConfig.marketId, ctx.newIndexPrice, ctx.secondOrderSizeDelta);

        // second market order
        perpsEngine.createMarketOrder(
            IOrderBranch.CreateMarketOrderParams({
                accountId: ctx.perpsAccountId,
                marketId: ctx.fuzzMarketConfig.marketId,
                sizeDelta: ctx.secondOrderSizeDelta
            })
        );

        ctx.secondMockSignedReport = getMockedSignedReport(ctx.fuzzMarketConfig.streamId, ctx.newIndexPrice);

        ctx.secondOrderExpectedPriceShiftPnlX18 = ctx.secondFillPriceX18.intoSD59x18().sub(
            ctx.firstFillPriceX18.intoSD59x18()
        ).mul(sd59x18(ctx.firstOrderSizeDelta));
        ctx.secondOrderExpectedPnl = unary(
            ctx.secondOrderFeeUsdX18.add(ud60x18(DEFAULT_SETTLEMENT_FEE).intoSD59x18())
        ).add(ctx.secondOrderExpectedPriceShiftPnlX18).intoInt256();

        changePrank({ msgSender: ctx.marketOrderKeeper });

        // it should emit a {LogSettleOrder} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit ISettlementBranch.LogSettleOrder({
            sender: ctx.marketOrderKeeper,
            accountId: ctx.perpsAccountId,
            marketId: ctx.fuzzMarketConfig.marketId,
            sizeDelta: ctx.secondOrderSizeDelta,
            fillPrice: ctx.secondFillPriceX18.intoUint256(),
            orderFeeUsd: ctx.secondOrderFeeUsdX18.intoInt256(),
            settlementFeeUsd: DEFAULT_SETTLEMENT_FEE,
            pnl: ctx.secondOrderExpectedPnl,
            fundingFeePerUnit: 0
        });
        // fill second order and close position
        console.log("filling second order: ");
        perpsEngine.fillMarketOrder(
            ctx.perpsAccountId, ctx.fuzzMarketConfig.marketId, feeRecipients, ctx.secondMockSignedReport
        );

        // TODO: assert after funding task is done
        // it should update the funding values

        // it should update the open interest and skew
        ctx.expectedOpenInterest = 0;
        ctx.expectedSkew = 0;
        (,, ctx.openInterestX18) = perpsEngine.getOpenInterest(ctx.fuzzMarketConfig.marketId);
        ctx.skewX18 = perpsEngine.getSkew(ctx.fuzzMarketConfig.marketId);
        assertAlmostEq(ctx.expectedOpenInterest, ctx.openInterestX18.intoUint256(), 1, "first fill: open interest");
        assertEq(ctx.expectedSkew, ctx.skewX18.intoInt256(), "first fill: skew");

        // TODO: assert after harnesses are done
        // it should update the account's active markets
        ctx.expectedActiveMarketId = ctx.fuzzMarketConfig.marketId;

        // TODO: assert after harnesses are done
        // it should update the account's position
        ctx.expectedPosition =
            Position.Data({ size: 0, lastInteractionPrice: 0, lastInteractionFundingFeePerUnit: 0 });

        // it should add the pnl into the account's margin
        ctx.expectedMarginBalanceUsd =
            int256(fuzzMarginPortfolio.marginValueUsd) + ctx.firstOrderExpectedPnl + ctx.secondOrderExpectedPnl;
        (ctx.marginBalanceUsdX18,,,) = perpsEngine.getAccountMarginBreakdown(ctx.perpsAccountId);
        console.log("returned margin bal: ");
        console.log(ctx.marginBalanceUsdX18.intoUD60x18().intoUint256());
        assertEq(ctx.expectedMarginBalanceUsd, ctx.marginBalanceUsdX18.intoInt256(), "first fill: margin balance");
    }
}
