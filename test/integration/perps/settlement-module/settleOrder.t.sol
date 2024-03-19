// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { BasicReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { MarketOrder } from "@zaros/markets/perps/storage/MarketOrder.sol";
import { Position } from "@zaros/markets/perps/storage/Position.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";

// PRB Math dependencies
import { ud60x18 } from "@prb-math/UD60x18.sol";
import { sd59x18 } from "@prb-math/SD59x18.sol";

contract SettleOrder_Integration_Test is Base_Integration_Shared_Test {
// function setUp() public override {
//     Base_Integration_Shared_Test.setUp();
//     changePrank({ msgSender: users.owner });
//     configureSystemParameters();
//     createMarkets();
//     changePrank({ msgSender: users.naruto });
// }

// function testFuzz_SettleOrder(uint256 initialMarginRate, uint256 marginValueUsd, bool isLong) external {
//     initialMarginRate =
//         bound({ x: initialMarginRate, min: ETH_USD_MARGIN_REQUIREMENTS, max: MAX_MARGIN_REQUIREMENTS });
//     marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });

//     deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

//     uint128 perpsAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
//     int128 sizeDelta = fuzzOrderSizeDelta(
//        FuzzOrderSizeDeltaParams({
//         perpsAccountId,
//         ETH_USD_MARKET_ID,
//         SettlementConfiguration.MARKET_ORDER_SETTLEMENT_ID,
//         initialMarginRate,
//         marginValueUsd,
//         ETH_USD_MAX_OI,
//         MOCK_ETH_USD_PRICE,
//         isLong
// })
//     );

//     perpsEngine.createMarketOrder({
//         accountId: perpsAccountId,
//         marketId: ETH_USD_MARKET_ID,
//         sizeDelta: sizeDelta,
//         acceptablePrice: 0
//     });

//     Position.Data memory expectedPosition = Position.Data({
//         size: sizeDelta,
//         lastInteractionPrice: uint128(MOCK_ETH_USD_PRICE),
//         lastInteractionFundingFeePerUnit: 0
//     });
//     // vm.expectEmit({ emitter: address(perpsEngine) });
//     // emit LogSettleOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedPosition);

//     bytes memory mockBasicSignedReport = getMockedSignedReport(MOCK_ETH_USD_STREAM_ID, MOCK_ETH_USD_PRICE, false);

//     changePrank({ msgSender: mockDefaultMarketOrderSettlementStrategy });
//     perpsEngine.settleMarketOrder({
//         accountId: perpsAccountId,
//         marketId: ETH_USD_MARKET_ID,
//         settlementFeeReceiver: mockDefaultMarketOrderSettlementStrategy,
//         priceData: mockBasicSignedReport
//     });
// }

// // function testFuzz_SettleOrderReducingSize(uint256 amountToDeposit) external {
// //     amountToDeposit = bound({ x: amountToDeposit, min: 1, max: USDZ_DEPOSIT_CAP });
// //     deal({ token: address(usdToken), to: users.naruto, give: amountToDeposit });

// //     BasicReport memory mockReport;
// //     mockReport.price = int192(int256(MOCK_ETH_USD_PRICE));

// //     uint128 perpsAccountId = createAccountAndDeposit(amountToDeposit, address(usdToken));

// //     MarketOrder.Payload memory payload = MarketOrder.Payload({
// //         accountId: perpsAccountId,
// //         marketId: ETH_USD_MARKET_ID,
// //         // initialMarginDelta: int128(10_000e18),
// //         sizeDelta: int128(50e18)
// //     });

// //     perpsEngine.createMarketOrder({ payload: payload, extraData: bytes("") });

// //     perpsEngine.settleMarketOrder({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID, report: mockReport
// // });

// //     MarketOrder.Payload memory newPayload = MarketOrder.Payload({
// //         accountId: perpsAccountId,
// //         marketId: ETH_USD_MARKET_ID,
// //         sizeDelta: int128(-25e18),
// //         acceptablePrice: 0
// //     });
// //     perpsEngine.createMarketOrder({ payload: newPayload });
// //     MarketOrder.Data memory sellOrder = perpsEngine.getActiveMarketOrder({ accountId: perpsAccountId });

// //     Position.Data memory expectedPosition = Position.Data({
// //         size: payload.sizeDelta + sellOrder.payload.sizeDelta,
// //         // initialMarginUsdX18: uint128(uint256(int256(payload.initialMarginDelta))),
// //         initialMarginUsdX18: 0,
// //         unrealizedPnlStored: 0,
// //         lastInteractionPrice: uint128(MOCK_ETH_USD_PRICE),
// //         lastInteractionFundingFeePerUnit: 0
// //     });

// //     vm.expectEmit({ emitter: address(perpsEngine) });
// //     emit LogSettleOrder(users.naruto, perpsAccountId, ETH_USD_MARKET_ID, expectedPosition);

// //     perpsEngine.settleMarketOrder({ accountId: perpsAccountId, marketId: ETH_USD_MARKET_ID, report: mockReport
// // });
// // }
}
