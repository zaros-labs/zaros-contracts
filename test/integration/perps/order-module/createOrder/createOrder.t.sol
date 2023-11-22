// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Order } from "@zaros/markets/perps/storage/Order.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract CreateOrder_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        createMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_CreateOrder(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint256 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        Order.Payload memory payload = Order.Payload({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            initialMarginDelta: int128(10_000e18),
            sizeDelta: int128(50e18),
            acceptablePrice: uint128(MOCK_ETH_USD_PRICE),
            orderType: Order.OrderType.MARKET
        });
        Order.Data memory expectedOrder =
            Order.Data({ id: 0, payload: payload, settlementTimestamp: uint248(block.timestamp) });

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreateOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedOrder);

        perpsEngine.createOrder({ payload: payload });
    }

    function testFuzz_CreateOrderMultiple(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint256 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        Order.Payload memory payload = Order.Payload({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            initialMarginDelta: int128(10_000e18),
            sizeDelta: int128(50e18),
            acceptablePrice: uint128(MOCK_ETH_USD_PRICE),
            orderType: Order.OrderType.MARKET
        });

        perpsEngine.createOrder({ payload: payload });

        Order.Data memory expectedOrder =
            Order.Data({ id: 1, payload: payload, settlementTimestamp: uint248(block.timestamp) });

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreateOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedOrder);

        perpsEngine.createOrder({ payload: payload });
    }
}
