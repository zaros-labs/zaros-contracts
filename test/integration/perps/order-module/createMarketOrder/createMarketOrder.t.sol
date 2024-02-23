// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { BasicReport, PremiumReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { Math } from "@zaros/utils/Math.sol";
import { IOrderModule } from "@zaros/markets/perps/interfaces/IOrderModule.sol";
import { MarketOrder } from "@zaros/markets/perps/storage/MarketOrder.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { ud60x18, UNIT as UD_UNIT } from "@prb-math/UD60x18.sol";
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

    function testFuzz_RevertWhen_TheAccountIdDoesNotExist(uint128 perpsAccountId, int128 sizeDelta) external {
        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountNotFound.selector, perpsAccountId, users.naruto)
        });
        perpsEngine.createMarketOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0
        });
    }

    modifier whenTheAccountIdExists() {
        _;
    }

    function testFuzz_RevertGiven_TheSenderIsNotAuthorized(int128 sizeDelta) external whenTheAccountIdExists {
        uint128 perpsAccountId = perpsEngine.createPerpsAccount();

        changePrank({ msgSender: users.sasuke });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountPermissionDenied.selector, perpsAccountId, users.sasuke)
        });
        perpsEngine.createMarketOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0
        });
    }

    modifier givenTheSenderIsAuthorized() {
        _;
    }

    function test_RevertWhen_TheSizeDeltaIsZero() external whenTheAccountIdExists givenTheSenderIsAuthorized {
        uint128 perpsAccountId = perpsEngine.createPerpsAccount();

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput.selector, "sizeDelta") });
        perpsEngine.createMarketOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: 0,
            acceptablePrice: 0
        });
    }

    modifier whenTheSizeDeltaIsNotZero() {
        _;
    }

    function testFuzz_RevertWhen_TheSizeDeltaIsLessThanTheMinTradeSize(
        uint256 marginValueUsd,
        bool isLong
    )
        external
        whenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
    {
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        SD59x18 sizeDeltaAbs = ud60x18(MIN_TRADE_SIZE_USD).sub(UD_UNIT).div(ud60x18(MOCK_ETH_USD_PRICE)).intoSD59x18();
        int128 sizeDelta = isLong ? sizeDeltaAbs.intoInt256().toInt128() : unary(sizeDeltaAbs).intoInt256().toInt128();
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        MarketOrder.Data memory expectedMarketOrder = MarketOrder.Data({
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0,
            timestamp: uint128(block.timestamp)
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.TradeSizeTooSmall.selector) });
        perpsEngine.createMarketOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0
        });
    }

    modifier whenTheSizeDeltaIsGreaterThanTheMinTradeSize() {
        _;
    }

    function testFuzz_RevertGiven_TheAccountWontMeetTheMarginRequirements(
        uint256 marginValueUsd,
        bool isLong
    )
        external
        whenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
    {
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        SD59x18 sizeDeltaAbs = Math.max(
            ud60x18(MIN_TRADE_SIZE_USD),
            ud60x18(ETH_USD_MARGIN_REQUIREMENTS_RATE).add(ud60x18(1e18)).div(ud60x18(marginValueUsd)).div(
                ud60x18(MOCK_ETH_USD_PRICE)
            )
        ).intoSD59x18();
        int128 sizeDelta = isLong ? sizeDeltaAbs.intoInt256().toInt128() : unary(sizeDeltaAbs).intoInt256().toInt128();
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        MarketOrder.Data memory expectedMarketOrder = MarketOrder.Data({
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0,
            timestamp: uint128(block.timestamp)
        });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.InsufficientMargin.selector) });
        perpsEngine.createMarketOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0
        });
    }

    modifier givenTheAccountWillMeetTheMarginRequirements() {
        _;
    }

    function testFuzz_RevertGiven_TheAccountWillReachThePositionsLimit(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong
    )
        external
        whenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
        givenTheAccountWillMeetTheMarginRequirements
    {
        initialMarginRate = bound({ x: initialMarginRate, min: ETH_USD_MARGIN_REQUIREMENTS_RATE, max: MAX_IMR });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });
        int128 sizeDelta = fuzzOrderSizeDelta(initialMarginRate, marginValueUsd, MOCK_ETH_USD_PRICE, isLong);

        changePrank({ msgSender: users.owner });
        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: 1,
            marketOrderMaxLifetime: MARKET_ORDER_MAX_LIFETIME,
            minTradeSizeUsdX18: MIN_TRADE_SIZE_USD,
            liquidationFeeUsdX18: LIQUIDATION_FEE_USD
        });

        changePrank({ msgSender: users.naruto });
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        perpsEngine.createMarketOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0
        });

        changePrank({ msgSender: mockDefaultMarketOrderSettlementStrategy });
        bytes memory mockBasicSignedReport = getMockedSignedReport(MOCK_ETH_USD_STREAM_ID, MOCK_ETH_USD_PRICE, false);

        mockSettleMarketOrder(perpsAccountId, ETH_USD_MARKET_ID, mockBasicSignedReport);

        changePrank({ msgSender: users.naruto });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MaxPositionsPerAccountReached.selector, perpsAccountId, 1, 1)
        });
        perpsEngine.createMarketOrder({
            accountId: perpsAccountId,
            marketId: BTC_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0
        });
    }

    modifier givenTheAccountWillNotReachThePositionsLimit() {
        _;
    }

    function testFuzz_RevertGiven_ThePerpMarketIsDisabled(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong
    )
        external
        whenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
        givenTheAccountWillMeetTheMarginRequirements
        givenTheAccountWillNotReachThePositionsLimit
    {
        initialMarginRate = bound({ x: initialMarginRate, min: ETH_USD_MARGIN_REQUIREMENTS_RATE, max: MAX_IMR });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        int128 sizeDelta = fuzzOrderSizeDelta(initialMarginRate, marginValueUsd, MOCK_ETH_USD_PRICE, isLong);
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        changePrank({ msgSender: users.owner });
        perpsEngine.updatePerpMarketStatus({ marketId: ETH_USD_MARKET_ID, enable: false });

        changePrank({ msgSender: users.naruto });

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.PerpMarketDisabled.selector, ETH_USD_MARKET_ID) });
        perpsEngine.createMarketOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0
        });
    }

    modifier givenThePerpMarketIsActive() {
        _;
    }

    function testFuzz_RevertGiven_ThereIsAPendingMarketOrder(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong
    )
        external
        whenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
        givenTheAccountWillMeetTheMarginRequirements
        givenTheAccountWillNotReachThePositionsLimit
        givenThePerpMarketIsActive
    {
        initialMarginRate = bound({ x: initialMarginRate, min: ETH_USD_MARGIN_REQUIREMENTS_RATE, max: MAX_IMR });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        int128 sizeDelta = fuzzOrderSizeDelta(initialMarginRate, marginValueUsd, MOCK_ETH_USD_PRICE, isLong);
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        perpsEngine.createMarketOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0
        });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.MarketOrderStillPending.selector, block.timestamp)
        });
        perpsEngine.createMarketOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0
        });
    }

    function testFuzz_GivenThereIsNoPendingMarketOrder(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong
    )
        external
        whenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        whenTheSizeDeltaIsGreaterThanTheMinTradeSize
        givenTheAccountWillMeetTheMarginRequirements
        givenTheAccountWillNotReachThePositionsLimit
        givenThePerpMarketIsActive
    {
        initialMarginRate = bound({ x: initialMarginRate, min: ETH_USD_MARGIN_REQUIREMENTS_RATE, max: MAX_IMR });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        int128 sizeDelta = fuzzOrderSizeDelta(initialMarginRate, marginValueUsd, MOCK_ETH_USD_PRICE, isLong);
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        MarketOrder.Data memory expectedMarketOrder = MarketOrder.Data({
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0,
            timestamp: uint128(block.timestamp)
        });

        // it should emit a {LogCreateMarketOrder} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit IOrderModule.LogCreateMarketOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedMarketOrder);
        perpsEngine.createMarketOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0
        });

        // it should create the market order
        MarketOrder.Data memory marketOrder = perpsEngine.getActiveMarketOrder({ accountId: perpsAccountId });

        assertEq(marketOrder.sizeDelta, sizeDelta, "createMarketOrder: sizeDelta");
        assertEq(marketOrder.acceptablePrice, 0, "createMarketOrder: acceptablePrice");
        assertEq(marketOrder.timestamp, block.timestamp, "createMarketOrder: timestamp");
    }
}
