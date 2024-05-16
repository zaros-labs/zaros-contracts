// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { Base_Integration_Shared_Test } from "test/integration/shared/BaseIntegration.t.sol";
import { IPerpsEngine } from "@zaros/perpetuals/PerpsEngine.sol";
import { OrderBranch } from "@zaros/perpetuals/branches/OrderBranch.sol";
import { SettlementConfiguration } from "@zaros/perpetuals/leaves/SettlementConfiguration.sol";
import { Markets } from "script/markets/Markets.sol";
import { Log as AutomationLog } from "@zaros/external/chainlink/interfaces/ILogAutomation.sol";
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";

import { MarketOrderKeeper } from "@zaros/external/chainlink/keepers/market-order/MarketOrderKeeper.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";

contract MarketOrderKeeper_CheckLog_Integration_Test is Base_Integration_Shared_Test {
    function setUp() public override {
        Base_Integration_Shared_Test.setUp();
        changePrank({ msgSender: users.owner });
        configureSystemParameters();

        createPerpMarkets();

        changePrank({ msgSender: users.naruto });
    }

    modifier givenInitializeContract() {
        _;
    }

    function testFuzz_RevertGiven_CallCheckLogFunction(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong,
        uint256 marketId
    )
        external
        givenInitializeContract
    {
        // TODO
        // changePrank({ msgSender: users.naruto });

        // MarketConfig memory fuzzMarketConfig = getFuzzMarketConfig(marketId);

        // initialMarginRate =
        //     bound({ x: initialMarginRate, min: fuzzMarketConfig.marginRequirements, max: MAX_MARGIN_REQUIREMENTS
        // });

        // marginValueUsd = bound({ x: marginValueUsd, min: USDZ_MIN_DEPOSIT_MARGIN, max: USDZ_DEPOSIT_CAP });
        // deal({ token: address(usdToken), to: users.naruto, give: marginValueUsd });

        // uint128 tradingAccountId = createAccountAndDeposit(marginValueUsd, address(usdToken));
        // int128 sizeDelta = fuzzOrderSizeDelta(
        //     FuzzOrderSizeDeltaParams({
        //         tradingAccountId: tradingAccountId,
        //         marketId: fuzzMarketConfig.marketId,
        //         settlementConfigurationId: SettlementConfiguration.MARKET_ORDER_CONFIGURATION_ID,
        //         initialMarginRate: ud60x18(initialMarginRate),
        //         marginValueUsd: ud60x18(marginValueUsd),
        //         maxOpenInterest: ud60x18(fuzzMarketConfig.maxOi),
        //         minTradeSize: ud60x18(fuzzMarketConfig.minTradeSize),
        //         price: ud60x18(fuzzMarketConfig.mockUsdPrice),
        //         isLong: isLong,
        //         shouldDiscountFees: true
        //     })
        // );

        // perpsEngine.createMarketOrder(
        //     OrderBranch.CreateMarketOrderParams({
        //         tradingAccountId: tradingAccountId,
        //         marketId: fuzzMarketConfig.marketId,
        //         sizeDelta: sizeDelta
        //     })
        // );

        // bytes memory empty;

        // bytes32[] memory topics = new bytes32[](4);
        // topics[0] = keccak256(abi.encode("Log(address,uint128,uint256)"));
        // topics[1] = keccak256(abi.encode(address(perpsEngine)));
        // topics[2] = keccak256(abi.encode(tradingAccountId));
        // topics[3] = keccak256(abi.encode(fuzzMarketConfig.marketId));

        // MarketOrder.Data memory marketOrder =
        //     MarketOrder.Data({ marketId: fuzzMarketConfig.marketId, sizeDelta: sizeDelta, timestamp: 0 });

        // bytes memory data = abi.encode(marketOrder);

        // AutomationLog memory mockedLog = AutomationLog({
        //     index: 0,
        //     timestamp: 0,
        //     txHash: 0,
        //     blockNumber: 0,
        //     blockHash: 0,
        //     source: address(0),
        //     topics: topics,
        //     data: data
        // });

        // address marketOrderKeeper = marketOrderKeepers[fuzzMarketConfig.marketId];
        // it should revert
        // MarketOrderKeeper(marketOrderKeeper).checkLog(mockedLog, empty);
    }
}
