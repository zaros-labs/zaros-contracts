// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { BasicReport, PremiumReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketOrder } from "@zaros/markets/perps/storage/MarketOrder.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18, unary } from "@prb-math/SD59x18.sol";

contract CreateMarketOrder_Integration_Test is Base_Integration_Shared_Test {
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

    // TODO: Implement
    function test_RevertGiven_TheAccountIsLiquidatable()
        external
        whenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
    {
        // it should revert
    }

    modifier givenTheAccountIsNotLiquidatable() {
        _;
    }

    // TODO: Implement
    function test_RevertGiven_TheAccountDoesNotHaveEnoughMargin()
        external
        whenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenTheAccountIsNotLiquidatable
    {
        // it should revert
    }

    modifier givenTheAccountHasEnoughMargin() {
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
        givenTheAccountIsNotLiquidatable
        givenTheAccountHasEnoughMargin
    {
        initialMarginRate = bound({ x: initialMarginRate, min: ETH_USD_MIN_IMR, max: MAX_IMR });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });
        int128 sizeDeltaAbs = int128(
            ud60x18(initialMarginRate).div(ud60x18(marginValueUsd)).div(ud60x18(MOCK_ETH_USD_PRICE)).intoSD59x18()
                .intoInt256()
        );
        int128 sizeDelta = isLong ? sizeDeltaAbs : -sizeDeltaAbs;

        changePrank({ msgSender: users.owner });
        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: 1,
            marketOrderMaxLifetime: MARKET_ORDER_MAX_LIFETIME
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
        givenTheAccountIsNotLiquidatable
        givenTheAccountHasEnoughMargin
        givenTheAccountWillNotReachThePositionsLimit
    {
        initialMarginRate = bound({ x: initialMarginRate, min: ETH_USD_MIN_IMR, max: MAX_IMR });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        int128 sizeDelta = fuzzMarketOrderSizeDelta(initialMarginRate, marginValueUsd, isLong);
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
        givenTheAccountIsNotLiquidatable
        givenTheAccountHasEnoughMargin
        givenTheAccountWillNotReachThePositionsLimit
        givenThePerpMarketIsActive
    {
        initialMarginRate = bound({ x: initialMarginRate, min: ETH_USD_MIN_IMR, max: MAX_IMR });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        int128 sizeDelta = fuzzMarketOrderSizeDelta(initialMarginRate, marginValueUsd, isLong);
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
        givenTheAccountIsNotLiquidatable
        givenTheAccountHasEnoughMargin
        givenTheAccountWillNotReachThePositionsLimit
        givenThePerpMarketIsActive
    {
        initialMarginRate = bound({ x: initialMarginRate, min: ETH_USD_MIN_IMR, max: MAX_IMR });
        marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

        deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        int128 sizeDelta = fuzzMarketOrderSizeDelta(initialMarginRate, marginValueUsd, isLong);
        uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));

        MarketOrder.Data memory expectedMarketOrder = MarketOrder.Data({
            marketId: ETH_USD_MARKET_ID,
            sizeDelta: sizeDelta,
            acceptablePrice: 0,
            timestamp: uint128(block.timestamp)
        });

        // it should emit a {LogCreateMarketOrder} event
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreateMarketOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedMarketOrder);
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
