// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Order } from "@zaros/markets/perps/storage/Order.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract CreateOrder_Integration_Concrete_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        createMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function test_CreateOrder() external {
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
        Order.Data memory expectedOrder = Order.Data({ id: 0, payload: payload, settlementTimestamp: block.timestamp });

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreateOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedOrder);

        perpsEngine.createOrder({ payload: payload });
    }

    function test_CreateOrderMultiple() external {
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

        Order.Data memory expectedOrder = Order.Data({ id: 1, payload: payload, settlementTimestamp: block.timestamp });

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreateOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedOrder);

        perpsEngine.createOrder({ payload: payload });
    }
}
