// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { PremiumReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { IOrderBranch } from "@zaros/perpetuals/interfaces/IOrderBranch.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

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
        uint256 marketIndex
    )
        external
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketIndex);

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
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketIndex);
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
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketIndex);
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
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, marketOrderKeeper, mockSignedReport);
    }

    modifier givenThePerpMarketIsEnabled() {
        _;
    }

    function testFuzz_RevertGiven_TheSettlementStrategyIsDisabled(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketIndex
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketIndex);
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
            fee: DATA_STREAMS_SETTLEMENT_FEE,
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
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, marketOrderKeeper, mockSignedReport);
    }

    function testFuzz_RevertGiven_TheReportVerificationFails(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketIndex
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketIndex);
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
            fee: DATA_STREAMS_SETTLEMENT_FEE,
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
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, marketOrderKeeper, mockSignedReport);
    }

    modifier givenTheReportVerificationPasses() {
        _;
    }

    function testFuzz_RevertGiven_TheDataStreamsReportIsInvalid(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketIndex
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        givenTheReportVerificationPasses
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketIndex);

        uint256 wrongMarketId = fuzzMarketConfig.marketId < FINAL_MARKET_ID
            ? fuzzMarketConfig.marketId + 1
            : fuzzMarketConfig.marketId - 1;

        uint256[2] memory marketsIdsRange;
        marketsIdsRange[0] = wrongMarketId;
        marketsIdsRange[1] = wrongMarketId;

        MarketConfig memory wrongMarketConfig = getFilteredMarketsConfig(marketsIdsRange)[0];

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
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, marketOrderKeeper, mockSignedReport);
    }

    modifier givenTheDataStreamsReportIsValid() {
        _;
    }

    function testFuzz_RevertGiven_TheAccountWontMeetTheMarginRequirement(
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketIndex
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        givenTheReportVerificationPasses
        givenTheDataStreamsReportIsValid
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketIndex);

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

        console.log("FROM TEST SUITE: ");
        console.log(marginBalanceUsdX18.intoUD60x18().intoUint256());
        console.log(requiredInitialMarginUsdX18.add(requiredMaintenanceMarginUsdX18).intoUint256());
        console.log(orderFeeUsdX18.add(settlementFeeUsdX18.intoSD59x18()).intoUD60x18().intoUint256());
        console.log(newMarginRequirements.intoUint256());
        console.log(fuzzMarketConfig.marginRequirements);
        console.log(newMarginRequirements.div(ud60x18(2e18)).intoUint256());

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
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, marketOrderKeeper, mockSignedReport);
    }

    modifier givenTheAccountWillMeetTheMarginRequirement() {
        _;
    }

    function testFuzz_RevertGiven_TheMarketsOILimitWillBeExceeded(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketIndex
    )
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
        givenTheReportVerificationPasses
        givenTheDataStreamsReportIsValid
        givenTheAccountWillMeetTheMarginRequirement
    {
        MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketIndex);

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
        perpsEngine.fillMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, marketOrderKeeper, mockSignedReport);
    }

    function test_GivenTheMarketsOILimitWontBeExceeded()
        external
        givenTheSenderIsTheKeeper
        givenTheMarketOrderExists
        givenThePerpMarketIsEnabled
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
        // it should pay the settlement fee
    }
}
