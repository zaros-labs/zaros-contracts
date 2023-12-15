// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
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

    function test_RevertGiven_TheAccountWillReachThePositionsLimit(
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
        // UD60x18 sizeDeltaAbsUsd = sd59x18(sizeDelta).abs().intoUd60x18().mul(ud60x18(MOCK_ETH_USD_PRICE));
        // uint256 marginValueUsd = sizeDeltaAbsUsd.mul(ud60x18(MOCK_ETH_IMR)).intoUint256();
        // int128 marginValueUsdInt = int128(int256(marginValueUsd));
        // sizeDelta = bound({ x: sizeDelta, min: -int128(int256(marginValueUsd)), max: minMaxSizeDelta });
        initialMarginRate = bound({ x: initialMarginRate, min: ETH_USD_MIN_IMR, max: MAX_IMR });
        marginValueUsd = bound({ x: marginValueUsd, min: 1, max: USDZ_DEPOSIT_CAP });
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

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.MaxPositionsPerAccountReached.selector, 1, 1) });
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

    function test_RevertGiven_ThePerpMarketIsNotActive()
        external
        whenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenTheAccountIsNotLiquidatable
        givenTheAccountHasEnoughMargin
        givenTheAccountWillNotReachThePositionsLimit
    {
        // it should revert
    }

    modifier givenThePerpMarketIsActive() {
        _;
    }

    function test_RevertGiven_ThereIsAPendingMarketOrder()
        external
        whenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenTheAccountIsNotLiquidatable
        givenTheAccountHasEnoughMargin
        givenTheAccountWillNotReachThePositionsLimit
        givenThePerpMarketIsActive
    {
        // it should revert
    }

    function test_GivenThereIsNoPendingMarketOrder()
        external
        whenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenTheAccountIsNotLiquidatable
        givenTheAccountHasEnoughMargin
        givenTheAccountWillNotReachThePositionsLimit
        givenThePerpMarketIsActive
    {
        // it should create the market order
        // it should emit a {LogCreateMarketOrder} event
    }

    // function testFuzz_CreateMarketOrder(uint256 amountToDeposit) external {
    //     amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
    //     deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

    //     uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

    //     MarketOrder.Payload memory payload =
    //         MarketOrder.Payload({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID, sizeDelta: int128(50e18)
    // });
    //     MarketOrder.Data memory expectedOrder =
    //         MarketOrder.Data({ payload: payload, timestamp: uint248(block.timestamp) });

    //     vm.expectEmit({ emitter: address(perpsEngine) });
    //     emit LogCreateMarketOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedOrder);

    //     perpsEngine.createMarketOrder({ payload: payload, extraData: bytes("") });
    // }

    // function testFuzz_CreateMarketOrderMultiple(uint256 amountToDeposit) external {
    //     amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
    //     deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

    //     uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

    //     MarketOrder.Payload memory payload =
    //         MarketOrder.Payload({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID, sizeDelta: int128(50e18)
    // });

    //     perpsEngine.createMarketOrder({ payload: payload, extraData: bytes("") });

    //     MarketOrder.Data memory expectedOrder =
    //         MarketOrder.Data({ payload: payload, timestamp: uint248(block.timestamp) });

    //     vm.expectEmit({ emitter: address(perpsEngine) });
    //     emit LogCreateMarketOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedOrder);

    //     perpsEngine.createMarketOrder({ payload: payload, extraData: bytes("") });
    // }
}
