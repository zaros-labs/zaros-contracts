// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { BasicReport, PremiumReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";
import { IOrderModule } from "@zaros/markets/perps/interfaces/IOrderModule.sol";
import { MarketOrder } from "@zaros/markets/perps/storage/MarketOrder.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18, UNIT as UD_UNIT } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

contract CreateMarketOrder_Integration_Test is Base_Integration_Shared_Test {
    using SafeCast for int256;

    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createMarkets();

        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertGiven_TheAccountIdDoesNotExist(
        uint128 perpsAccountId,
        int128 sizeDelta,
        uint256 marketIndex
    )
        external
    {
        (MarketConfig memory fuzzMarketConfig) =
            getFuzzMarketConfig(marketIndex);

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, perpsAccountId, users.naruto)
        });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                acceptablePrice: 0
            })
        );
    }

    modifier givenTheAccountIdExists() {
        _;
    }

    function testFuzz_RevertGiven_TheSenderIsNotAuthorized(
        int128 sizeDelta,
        uint256 marketIndex
    )
        external
        givenTheAccountIdExists
    {
        (MarketConfig memory fuzzMarketConfig) =
            getFuzzMarketConfig(marketIndex);

        uint128 perpsAccountId = perpsEngine.createPerpsAccount();

        changePrank({ msgSender: users.sasuke });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountPermissionDenied.selector, perpsAccountId, users.sasuke)
        });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                acceptablePrice: 0
            })
        );
    }

    modifier givenTheSenderIsAuthorized() {
        _;
    }

    function test_RevertWhen_TheSizeDeltaIsZero(uint256 marketIndex)
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
    {
        (MarketConfig memory fuzzMarketConfig) =
            getFuzzMarketConfig(marketIndex);

        uint128 perpsAccountId = perpsEngine.createPerpsAccount();

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "sizeDelta") });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: 0,
                acceptablePrice: 0
            })
        );
    }

    modifier whenTheSizeDeltaIsNotZero() {
        _;
    }

    function testFuzz_RevertGiven_ThePerpMarketIsDisabled(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketIndex
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
    {
        (MarketConfig memory fuzzMarketConfig) =
            getFuzzMarketConfig(marketIndex);

        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketStatus({ marketId: fuzzMarketConfig.marketId, enable: false });

        changePrank({ msgSender: users.naruto });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.PerpMarketDisabled.selector, fuzzMarketConfig.marketId)
        });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                acceptablePrice: 0
            })
        );
    }

    modifier givenThePerpMarketIsEnabled() {
        _;
    }

    function testFuzz_RevertWhen_TheSizeDeltaIsLessThanTheMinTradeSize(
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketIndex
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
    {
        (MarketConfig memory fuzzMarketConfig) =
            getFuzzMarketConfig(marketIndex);

        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });
        SD59x18 sizeDeltaAbs = ud60x18(fuzzMarketConfig.minTradeSize).intoSD59x18().sub(sd59x18(1));

        int128 sizeDelta = isLong ? sizeDeltaAbs.intoInt256().toInt128() : unary(sizeDeltaAbs).intoInt256().toInt128();
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.TradeSizeTooSmall.selector) });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                acceptablePrice: 0
            })
        );
    }

    modifier whenTheSizeDeltaIsGreaterThanTheMinTradeSize() {
        _;
    }

    function testFuzz_RevertGiven_ThePerpMarketWillReachTheOILimit(
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketIndex
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
    {
        (MarketConfig memory fuzzMarketConfig) =
            getFuzzMarketConfig(marketIndex);

        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });
        SD59x18 sizeDeltaAbs = ud60x18(fuzzMarketConfig.maxOi).intoSD59x18().add(sd59x18(1));

        int128 sizeDelta = isLong ? sizeDeltaAbs.intoInt256().toInt128() : unary(sizeDeltaAbs).intoInt256().toInt128();
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.ExceedsOpenInterestLimit.selector,
                fuzzMarketConfig.marketId,
                fuzzMarketConfig.maxOi,
                sizeDeltaAbs.intoUint256()
                )
        });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                acceptablePrice: 0
            })
        );
    }

    modifier givenThePerpMarketWontReachTheOILimit() {
        _;
    }

    function testFuzz_RevertGiven_TheAccountHasReachedThePositionsLimit(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketIndex
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
        givenThePerpMarketWontReachTheOILimit
    {
        uint256 secondMarketIndex = 0;
        if (marketIndex < finalMarketIndex - 1) {
            secondMarketIndex++;
        }

        (MarketConfig memory fuzzMarketConfig) = getFuzzMarketConfig(0);
        (MarketConfig memory secondFuzzMarketConfig) = getFuzzMarketConfig(1);

        initialMarginRate = bound({
            x: initialMarginRate,
            min: fuzzMarketConfig.marginRequirements + secondFuzzMarketConfig.marginRequirements,
            max: MAX_MARGIN_REQUIREMENTS * 2
        });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 firstOrderSizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        changePrank({ msgSender: users.owner });
        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: 1,
            marketOrderMaxLifetime: MARKET_ORDER_MAX_LIFETIME,
            liquidationFeeUsdX18: LIQUIDATION_FEE_USD
        });

        changePrank({ msgSender: users.naruto });

        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: firstOrderSizeDelta,
                acceptablePrice: 0
            })
        );

        changePrank({ msgSender: marketOrderKeepers[fuzzMarketConfig.marketId] });
        bytes memory mockBasicSignedReport =
            getMockedSignedReport(fuzzMarketConfig.streamId, fuzzMarketConfig.mockUsdPrice, false);

        mockSettleMarketOrder(perpsAccountId, fuzzMarketConfig.marketId, mockBasicSignedReport);

        changePrank({ msgSender: users.naruto });

        int128 secondOrderSizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: secondFuzzMarketConfig.marketId,
                settlementId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(secondFuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(secondFuzzMarketConfig.minTradeSize),
                price: ud60x18(secondFuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MaxPositionsPerAccountReached.selector, perpsAccountId, 1, 1)
        });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: secondFuzzMarketConfig.marketId,
                sizeDelta: secondOrderSizeDelta,
                acceptablePrice: 0
            })
        );
    }

    modifier givenTheAccountHasNotReachedThePositionsLimit() {
        _;
    }

    function testFuzz_RevertGiven_TheAccountWontMeetTheMarginRequirements(
        uint256 marginValueUsd,
        uint256 initialMarginRate,
        bool isLong,
        uint256 marketIndex
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
        givenThePerpMarketWontReachTheOILimit
        givenTheAccountHasNotReachedThePositionsLimit
    {
        (MarketConfig memory fuzzMarketConfig) =
            getFuzzMarketConfig(marketIndex);

        UD60x18 maxMarginValueUsd = ud60x18(fuzzMarketConfig.marginRequirements).mul(ud60x18(ETH_USD_MAX_OI));
        marginValueUsd =
            bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: maxMarginValueUsd.intoUint256() });
        initialMarginRate = bound({ x: initialMarginRate, min: 1, max: fuzzMarketConfig.marginRequirements - 1 });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: false
            })
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
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                acceptablePrice: 0
            })
        );
    }

    modifier givenTheAccountWillMeetTheMarginRequirements() {
        _;
    }

    function testFuzz_RevertGiven_ThereIsAPendingMarketOrder(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketIndex
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
        givenThePerpMarketWontReachTheOILimit
        givenTheAccountHasNotReachedThePositionsLimit
        givenTheAccountWillMeetTheMarginRequirements
    {
        (MarketConfig memory fuzzMarketConfig) =
            getFuzzMarketConfig(marketIndex);

        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
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
                sizeDelta: sizeDelta,
                acceptablePrice: 0
            })
        );

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MarketOrderStillPending.selector, block.timestamp)
        });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                acceptablePrice: 0
            })
        );
    }

    function testFuzz_GivenThereIsNoPendingMarketOrder(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketIndex
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
        givenThePerpMarketWontReachTheOILimit
        givenTheAccountHasNotReachedThePositionsLimit
        givenTheAccountWillMeetTheMarginRequirements
    {
        (MarketConfig memory fuzzMarketConfig) =
            getFuzzMarketConfig(marketIndex);

        initialMarginRate =
            bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                settlementId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
                minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
                price: ud60x18(fuzzMarketConfig.mockUsdPrice),
                isLong: isLong,
                shouldDiscountFees: true
            })
        );

        MarketOrder.Data memory expectedMarketOrder = MarketOrder.Data({
            marketId: fuzzMarketConfig.marketId,
            sizeDelta: sizeDelta,
            acceptablePrice: 0,
            timestamp: uint128(block.timestamp)
        });

        // it should emit a {LogCreateMarketOrder} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit IOrderModule.LogCreateMarketOrder(
            users.naruto, perpsAccountId, fuzzMarketConfig.marketId, expectedMarketOrder
        );
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: fuzzMarketConfig.marketId,
                sizeDelta: sizeDelta,
                acceptablePrice: 0
            })
        );

        // it should create the market order
        MarketOrder.Data memory marketOrder = perpsEngine.getActiveMarketOrder({ accountId: perpsAccountId });

        assertEq(marketOrder.sizeDelta, sizeDelta, "createMarketOrder: sizeDelta");
        assertEq(marketOrder.acceptablePrice, 0, "createMarketOrder: acceptablePrice");
        assertEq(marketOrder.timestamp, block.timestamp, "createMarketOrder: timestamp");
    }
}
