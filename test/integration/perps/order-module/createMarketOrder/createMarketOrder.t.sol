// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { MarketOrder } from "@zaros/markets/perps/storage/MarketOrder.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract CreateMarketOrder_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        createMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_RevertWhen_TheAccountIdDoesNotExist(uint128 perpsAccountId, int128 sizeDelta) external {
        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.AccountNotFound, perpsAccountId, users.naruto) });
        perpsEngine.createMarketOrdder({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID, sizeDelta: sizeDelta });
    }

    modifier whenTheAccountIdExists() {
        _;
    }

    function testFuzz_RevertGiven_TheSenderIsNotAuthorized(int128 sizeDelta) external whenTheAccountIdExists {
        uint128 perpsAccountId = perpsEngine.createAccount();

        changePrank({ msgSender: users.sasuke });

        // it should revert
        vm.expectRevert({
            revertData: abi.encodeWithSelector(Errors.AccountPermissionDenied, perpsAccountId, users.sasuke)
        });
        perpsEngine.createMarketOrdder({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID, sizeDelta: sizeDelta });
    }

    modifier givenTheSenderIsAuthorized() {
        _;
    }

    function test_RevertWhen_TheSizeDeltaIsZero() external whenTheAccountIdExists givenTheSenderIsAuthorized {
        uint128 perpsAccountId = perpsEngine.createAccount();

        // it should revert
        vm.expectRevert({ revertData: abi.encodeWithSelector(Errors.ZeroInput, "sizeDelta") });
        perpsEngine.createMarketOrdder({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID, sizeDelta: 0 });
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

    function test_RevertGiven_TheAccountWillReachThePositionsLimit()
        external
        whenTheAccountIdExists
        givenTheSenderIsAuthorized
        whenTheSizeDeltaIsNotZero
        givenTheAccountIsNotLiquidatable
        givenTheAccountHasEnoughMargin
    {
        // it should revert
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

    function testFuzz_CreateMarketOrder(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        MarketOrder.Payload memory payload =
            MarketOrder.Payload({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID, sizeDelta: int128(50e18) });
        MarketOrder.Data memory expectedOrder =
            MarketOrder.Data({ payload: payload, timestamp: uint248(block.timestamp) });

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreateMarketOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedOrder);

        perpsEngine.createMarketOrder({ payload: payload, extraData: bytes("") });
    }

    function testFuzz_CreateMarketOrderMultiple(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        MarketOrder.Payload memory payload =
            MarketOrder.Payload({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID, sizeDelta: int128(50e18) });

        perpsEngine.createMarketOrder({ payload: payload, extraData: bytes("") });

        MarketOrder.Data memory expectedOrder =
            MarketOrder.Data({ payload: payload, timestamp: uint248(block.timestamp) });

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreateMarketOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedOrder);

        perpsEngine.createMarketOrder({ payload: payload, extraData: bytes("") });
    }
}
