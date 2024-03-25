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

    function testFuzz_RevertGiven_TheAccountIdDoesNotExist(uint128 perpsAccountId, int128 sizeDelta) external {
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, perpsAccountId, users.naruto)
        });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
                sizeDelta: sizeDelta,
                acceptablePrice: 0
            })
        );
    }

    modifier givenTheAccountIdExists() {
        _;
    }

    function testFuzz_RevertGiven_TheSenderIsNotAuthorized(int128 sizeDelta) external givenTheAccountIdExists {
        uint128 perpsAccountId = perpsEngine.createPerpsAccount();

        changePrank({ msgSender: users.sasuke });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountPermissionDenied.selector, perpsAccountId, users.sasuke)
        });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
                sizeDelta: sizeDelta,
                acceptablePrice: 0
            })
        );
    }

    modifier givenTheSenderIsAuthorized() {
        _;
    }

    function test_RevertWhen_TheSizeDeltaIsZero() external givenTheAccountIdExists givenTheSenderIsAuthorized {
        uint128 perpsAccountId = perpsEngine.createPerpsAccount();

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "sizeDelta") });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
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
        bool isLong
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
    {
        initialMarginRate =
            bound({ x: initialMarginRate, min: ETH_USD_MARGIN_REQUIREMENTS, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
                settlementId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(ETH_USD_MAX_OI),
                minTradeSize: ud60x18(ETH_USD_MIN_TRADE_SIZE),
                price: ud60x18(MOCK_ETH_USD_PRICE),
                isLong: isLong
            })
        );

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketStatus({ marketId: ETH_USD_MARKET_ID, enable: false });

        changePrank({ msgSender: users.naruto });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.PerpMarketDisabled.selector, ETH_USD_MARKET_ID) });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
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
        bool isLong
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
    {
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });
        SD59x18 sizeDeltaAbs = ud60x18(ETH_USD_MIN_TRADE_SIZE).intoSD59x18().sub(sd59x18(1));

        int128 sizeDelta = isLong ? sizeDeltaAbs.intoInt256().toInt128() : unary(sizeDeltaAbs).intoInt256().toInt128();
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.TradeSizeTooSmall.selector) });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
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
        bool isLong
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
    {
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });
        SD59x18 sizeDeltaAbs = ud60x18(ETH_USD_MAX_OI).intoSD59x18().add(sd59x18(1));

        int128 sizeDelta = isLong ? sizeDeltaAbs.intoInt256().toInt128() : unary(sizeDeltaAbs).intoInt256().toInt128();
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(
                Errors.ExceedsOpenInterestLimit.selector, ETH_USD_MARKET_ID, ETH_USD_MAX_OI, sizeDeltaAbs.intoUint256()
                )
        });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
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
        bool isLong
    )
        external
        givenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenThePerpMarketIsEnabled
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
        givenThePerpMarketWontReachTheOILimit
    {
        initialMarginRate = bound({
            x: initialMarginRate,
            min: ETH_USD_MARGIN_REQUIREMENTS + BTC_USD_MARGIN_REQUIREMENTS,
            max: MAX_MARGIN_REQUIREMENTS * 2
        });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 firstOrderSizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
                settlementId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(ETH_USD_MAX_OI),
                minTradeSize: ud60x18(ETH_USD_MIN_TRADE_SIZE),
                price: ud60x18(MOCK_ETH_USD_PRICE),
                isLong: isLong
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
                marketId: ETH_USD_MARKET_ID,
                sizeDelta: firstOrderSizeDelta,
                acceptablePrice: 0
            })
        );

        changePrank({ msgSender: mockDefaultMarketOrderSettlementStrategy });
        bytes memory mockBasicSignedReport = getMockedSignedReport(MOCK_ETH_USD_STREAM_ID, MOCK_ETH_USD_PRICE, false);

        mockSettleMarketOrder(perpsAccountId, ETH_USD_MARKET_ID, mockBasicSignedReport);

        changePrank({ msgSender: users.naruto });

        int128 secondOrderSizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: BTC_USD_MARKET_ID,
                settlementId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(BTC_USD_MAX_OI),
                minTradeSize: ud60x18(BTC_USD_MIN_TRADE_SIZE),
                price: ud60x18(MOCK_BTC_USD_PRICE),
                isLong: isLong
            })
        );

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MaxPositionsPerAccountReached.selector, perpsAccountId, 1, 1)
        });
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: BTC_USD_MARKET_ID,
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
        bool isLong
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
        UD60x18 maxMarginValueUsd = ud60x18(ETH_USD_MARGIN_REQUIREMENTS).mul(ud60x18(ETH_USD_MAX_OI));
        marginValueUsd =
            bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: maxMarginValueUsd.intoUint256() });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint256 initialMarginRate = ETH_USD_MARGIN_REQUIREMENTS / 2;
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
                settlementId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(ETH_USD_MAX_OI),
                minTradeSize: ud60x18(ETH_USD_MIN_TRADE_SIZE),
                price: ud60x18(MOCK_ETH_USD_PRICE),
                isLong: isLong
            })
        );

        (
            SD59x18 marginBalanceUsdX18,
            UD60x18 requiredInitialMarginUsdX18,
            UD60x18 requiredMaintenanceMarginUsdX18,
            SD59x18 orderFeeUsdX18,
            UD60x18 settlementFeeUsdX18,
        ) = perpsEngine.simulateTrade(perpsAccountId, ETH_USD_MARKET_ID, 0, sizeDelta);

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
                marketId: ETH_USD_MARKET_ID,
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
        bool isLong
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
        initialMarginRate =
            bound({ x: initialMarginRate, min: ETH_USD_MARGIN_REQUIREMENTS, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
                settlementId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(ETH_USD_MAX_OI),
                minTradeSize: ud60x18(ETH_USD_MIN_TRADE_SIZE),
                price: ud60x18(MOCK_ETH_USD_PRICE),
                isLong: isLong
            })
        );

        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
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
                marketId: ETH_USD_MARKET_ID,
                sizeDelta: sizeDelta,
                acceptablePrice: 0
            })
        );
    }

    function testFuzz_GivenThereIsNoPendingMarketOrder(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong
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
        initialMarginRate =
            bound({ x: initialMarginRate, min: ETH_USD_MARGIN_REQUIREMENTS, max: MAX_MARGIN_REQUIREMENTS });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        int128 sizeDelta = fuzzOrderSizeDelta(
            FuzzOrderSizeDeltaParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
                settlementId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
                initialMarginRate: ud60x18(initialMarginRate),
                marginValueUsd: ud60x18(marginValueUsd),
                maxOpenInterest: ud60x18(ETH_USD_MAX_OI),
                minTradeSize: ud60x18(ETH_USD_MIN_TRADE_SIZE),
                price: ud60x18(MOCK_ETH_USD_PRICE),
                isLong: isLong
            })
        );

        MarketOrder.Data memory expectedMarketOrder = MarketOrder.Data({
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0,
            timestamp: uint128(block.timestamp)
        });

        // it should emit a {LogCreateMarketOrder} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit IOrderModule.LogCreateMarketOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedMarketOrder);
        perpsEngine.createMarketOrder(
            IOrderModule.CreateMarketOrderParams({
                accountId: perpsAccountId,
                marketId: ETH_USD_MARKET_ID,
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
