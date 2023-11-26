// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { BasicReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { MarketOrder } from "@zaros/markets/perps/storage/MarketOrder.sol";
import { Position } from "@zaros/markets/perps/storage/Position.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract SettleOrder_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        createMarkets();
        changePrank({ msgSender: users.naruto });
    }

    function testFuzz_SettleOrder(uint256 amountToDeposit) external {
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
        MarketOrder.Data memory marketOrder =
            perpsEngine.getOrders({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID })[0];

        Position.Data memory expectedPosition = Position.Data({
            size: marketOrder.payload.sizeDelta,
            initialMargin: uint128(uint256(int256(marketOrder.payload.initialMarginDelta))),
            unrealizedPnlStored: 0,
            lastInteractionPrice: uint128(MOCK_ETH_USD_PRICE),
            lastInteractionFundingFeePerUnit: 0
        });
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogSettleOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, marketOrder.id, expectedPosition);

        BasicReport memory mockReport;
        mockReport.price = int192(int256(MOCK_ETH_USD_PRICE));

        perpsEngine.settleOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            orderId: marketOrder.id,
            report: mockReport
        });
    }

    function testFuzz_SettleOrderReducingSize(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        BasicReport memory mockReport;
        mockReport.price = int192(int256(MOCK_ETH_USD_PRICE));

        uint256 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        MarketOrder.Payload memory payload = MarketOrder.Payload({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            initialMarginDelta: int128(10_000e18),
            sizeDelta: int128(50e18),
            acceptablePrice: uint128(MOCK_ETH_USD_PRICE)
        });

        perpsEngine.createMarketOrder({ payload: payload });

        perpsEngine.settleOrder({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            orderId: 0,
            report: mockReport
        });

        MarketOrder.Payload memory newPayload = MarketOrder.Payload({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            initialMarginDelta: int128(0),
            sizeDelta: int128(-25e18),
            acceptablePrice: uint128(MOCK_ETH_USD_PRICE)
        });
        perpsEngine.createMarketOrder({ payload: newPayload });
        MarketOrder.Data memory sellOrder =
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
            report: mockReport
        });
    }
}
