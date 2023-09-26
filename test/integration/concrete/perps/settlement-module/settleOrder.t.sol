// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Order } from "@zaros/markets/perps/storage/Order.sol";
import { Position } from "@zaros/markets/perps/storage/Position.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract SettleOrder_Integration_Concrete_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        createMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_SettleOrder() external {
        uint256 amount = 100_000e18;

        uint256 perpsAccountId = _createAccountAndDeposit(amount, address(usdToken));

        Order.Payload memory payload = Order.Payload({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            initialMarginDelta: int128(10_000e18),
            sizeDelta: int128(50e18),
            acceptablePrice: uint128(MOCK_ETH_USD_PRICE),
            orderType: Order.OrderType.MARKET
        });
        perpsEngine.createOrder({ payload: payload });
        Order.Data memory order = perpsEngine.getOrders({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID })[0];

        Position.Data memory expectedPosition = Position.Data({
            size: order.payload.sizeDelta,
            initialMargin: uint128(uint256(int256(order.payload.initialMarginDelta))),
            unrealizedPnlStored: 0,
            lastInteractionPrice: uint128(MOCK_ETH_USD_PRICE),
            lastInteractionFundingFeePerUnit: 0
        });
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogSettleOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, order.id, expectedPosition);

        perpsEngine.settleOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            orderId: order.id,
            price: MOCK_ETH_USD_PRICE
        });
    }

    function test_SettleOrderReducingSize() external {
        uint256 amount = 100_000e18;

        uint256 perpsAccountId = _createAccountAndDeposit(amount, address(usdToken));

        Order.Payload memory payload = Order.Payload({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            initialMarginDelta: int128(10_000e18),
            sizeDelta: int128(50e18),
            acceptablePrice: uint128(MOCK_ETH_USD_PRICE),
            orderType: Order.OrderType.MARKET
        });

        perpsEngine.createOrder({ payload: payload });

        perpsEngine.settleOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            orderId: 0,
            price: MOCK_ETH_USD_PRICE
        });

        Order.Payload memory newPayload = Order.Payload({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            initialMarginDelta: int128(0),
            sizeDelta: int128(-25e18),
            acceptablePrice: uint128(MOCK_ETH_USD_PRICE),
            orderType: Order.OrderType.MARKET
        });
        perpsEngine.createOrder({ payload: newPayload });
        Order.Data memory sellOrder =
            perpsEngine.getOrders({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID })[1];

        Position.Data memory expectedPosition = Position.Data({
            size: payload.sizeDelta + sellOrder.payload.sizeDelta,
            initialMargin: uint128(uint256(int256(payload.initialMarginDelta))),
            unrealizedPnlStored: 0,
            lastInteractionPrice: uint128(MOCK_ETH_USD_PRICE),
            lastInteractionFundingFeePerUnit: 0
        });

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogSettleOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, sellOrder.id, expectedPosition);

        perpsEngine.settleOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            orderId: sellOrder.id,
            price: MOCK_ETH_USD_PRICE
        });
    }
}
