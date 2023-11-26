// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
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

    function testFuzz_CreateMarketOrder(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint256 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        MarketOrder.Payload memory payload = MarketOrder.Payload({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            initialMarginDelta: int128(10_000e18),
            sizeDelta: int128(50e18),
            acceptablePrice: uint128(MOCK_ETH_USD_PRICE)
        });
        MarketOrder.Data memory expectedOrder =
            MarketOrder.Data({ id: 0, payload: payload, timestamp: uint248(block.timestamp) });

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreateMarketOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedOrder);

        perpsEngine.createMarketOrder({ payload: payload });
    }

    function testFuzz_CreateMarketOrderMultiple(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        uint256 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        MarketOrder.Payload memory payload = MarketOrder.Payload({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            initialMarginDelta: int128(10_000e18),
            sizeDelta: int128(50e18),
            acceptablePrice: uint128(MOCK_ETH_USD_PRICE)
        });

        perpsEngine.createMarketOrder({ payload: payload });

        MarketOrder.Data memory expectedOrder =
            MarketOrder.Data({ id: 1, payload: payload, timestamp: uint248(block.timestamp) });

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogCreateMarketOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedOrder);

        perpsEngine.createMarketOrder({ payload: payload });
    }
}
