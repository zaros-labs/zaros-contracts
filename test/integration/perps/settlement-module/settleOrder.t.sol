// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { BasicReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { Order } from "@zaros/markets/perps/storage/Order.sol";
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

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        Order.Payload memory payload = Order.Payload({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            // initialMarginDelta: int128(10_000e18),
            sizeDelta: int128(50e18)
        });
        perpsEngine.createMarketOrder({ payload: payload });
        Order.Market memory marketOrder =
            perpsEngine.getActiveMarketOrder({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID });

        Position.Data memory expectedPosition = Position.Data({
            size: marketOrder.payload.sizeDelta,
            // initialMargin: uint128(uint256(int256(marketOrder.payload.initialMarginDelta))),
            initialMargin: 0,
            unrealizedPnlStored: 0,
            lastInteractionPrice: uint128(MOCK_ETH_USD_PRICE),
            lastInteractionFundingFeePerUnit: 0
        });
        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogSettleOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedPosition);

        BasicReport memory mockReport;
        mockReport.price = int192(int256(MOCK_ETH_USD_PRICE));

        perpsEngine.settleMarketOrder({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID, report: mockReport });
    }

    function testFuzz_SettleOrderReducingSize(uint256 amountToDeposit) external {
        amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
        deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

        BasicReport memory mockReport;
        mockReport.price = int192(int256(MOCK_ETH_USD_PRICE));

        uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

        Order.Payload memory payload = Order.Payload({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            // initialMarginDelta: int128(10_000e18),
            sizeDelta: int128(50e18)
        });

        perpsEngine.createMarketOrder({ payload: payload });

        perpsEngine.settleMarketOrder({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID, report: mockReport });

        Order.Payload memory newPayload = Order.Payload({
            accountId: perpsAccountId,
            marketId: ETH_USD_MARKET_ID,
            // initialMarginDelta: int128(0),
            sizeDelta: int128(-25e18)
        });
        perpsEngine.createMarketOrder({ payload: newPayload });
        Order.Market memory sellOrder =
            perpsEngine.getActiveMarketOrder({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID });

        Position.Data memory expectedPosition = Position.Data({
            size: payload.sizeDelta + sellOrder.payload.sizeDelta,
            // initialMargin: uint128(uint256(int256(payload.initialMarginDelta))),
            initialMargin: 0,
            unrealizedPnlStored: 0,
            lastInteractionPrice: uint128(MOCK_ETH_USD_PRICE),
            lastInteractionFundingFeePerUnit: 0
        });

        vm.expectEmit({ emitter: address(perpsEngine) });
        emit LogSettleOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedPosition);

        perpsEngine.settleMarketOrder({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID, report: mockReport });
    }
}
