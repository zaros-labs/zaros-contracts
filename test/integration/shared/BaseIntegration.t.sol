// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IFeeManager } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { BasicReport, PremiumReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Math } from "@zaros/utils/Math.sol";
import { IGlobalConfigurationModule } from "@zaros/markets/perps/interfaces/IGlobalConfigurationModule.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { Base_Test } from "test/Base.t.sol";
import { MockChainlinkFeeManager } from "test/mocks/MockChainlinkFeeManager.sol";
import { MockChainlinkVerifier } from "test/mocks/MockChainlinkVerifier.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { SD59x18, sd59x18, unary } from "@prb-math/SD59x18.sol";
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

import "forge-std/console.sol";

abstract contract Base_Integration_Shared_Test is Base_Test {
    using Math for UD60x18;
    using SafeCast for int256;

    address internal mockChainlinkFeeManager;
    address internal mockChainlinkVerifier;

    /// @dev TODO: think about forking tests
    mapping(uint256 marketId => address upkeep) internal marketOrderUpkeeps;
    address internal mockDefaultMarketOrderSettlementStrategy = vm.addr({ privateKey: 0x04 });

    /// @dev BTC / USD market configuration variables.
    SettlementConfiguration.DataStreamsMarketStrategy internal btcUsdMarketOrderConfigurationData;
    SettlementConfiguration.Data internal btcUsdMarketOrderConfiguration;
    // TODO: update limit order strategy and move the market's strategies definition to a separate file.
    SettlementConfiguration.Data internal btcUsdLimitOrderConfiguration;

    SettlementConfiguration.Data[] internal btcUsdCustomOrderStrategies;

    /// @dev ETH / USD market configuration variables.
    SettlementConfiguration.DataStreamsMarketStrategy internal ethUsdMarketOrderConfigurationData;
    SettlementConfiguration.Data internal ethUsdMarketOrderConfiguration;
    // TODO: update limit order strategy and move the market's strategies definition to a separate file.
    SettlementConfiguration.Data internal ethUsdLimitOrderConfiguration;

    SettlementConfiguration.Data[] internal ethUsdCustomOrderStrategies;

    function setUp() public virtual override {
        Base_Test.setUp();

        mockChainlinkFeeManager = address(new MockChainlinkFeeManager());
        mockChainlinkVerifier = address(new MockChainlinkVerifier(IFeeManager(mockChainlinkFeeManager)));

        /// @dev BTC / USD market configuration variables.
        // marketOrderUpkeeps[BTC_USD_MARKET_ID] = address(new MarketOrderUpkeep());
        marketOrderUpkeeps[BTC_USD_MARKET_ID] = vm.addr({ privateKey: 0x05 });

        btcUsdMarketOrderConfigurationData = SettlementConfiguration.DataStreamsMarketStrategy({
            chainlinkVerifier: IVerifierProxy(mockChainlinkVerifier),
            streamId: MOCK_BTC_USD_STREAM_ID,
            feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
            queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
            settlementDelay: ETH_USD_SETTLEMENT_DELAY,
            isPremium: false
        });
        // TODO: set price adapter
        btcUsdMarketOrderConfiguration = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_MARKET,
            isEnabled: true,
            fee: DATA_STREAMS_SETTLEMENT_FEE,
            settlementStrategy: mockDefaultMarketOrderSettlementStrategy,
            data: abi.encode(btcUsdMarketOrderConfigurationData)
        });

        // TODO: update limit order strategy and move the market's strategies definition to a separate file.
        // TODO: set price adapter
        btcUsdLimitOrderConfiguration = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_CUSTOM,
            isEnabled: true,
            fee: DATA_STREAMS_SETTLEMENT_FEE,
            settlementStrategy: mockDefaultMarketOrderSettlementStrategy,
            data: abi.encode(btcUsdMarketOrderConfigurationData)
        });

        /// @dev ETH / USD market configuration variables.
        marketOrderUpkeeps[ETH_USD_MARKET_ID] = vm.addr({ privateKey: 0x06 });

        ethUsdMarketOrderConfigurationData = SettlementConfiguration.DataStreamsMarketStrategy({
            chainlinkVerifier: IVerifierProxy((mockChainlinkVerifier)),
            streamId: MOCK_ETH_USD_STREAM_ID,
            feedLabel: DATA_STREAMS_FEED_PARAM_KEY,
            queryLabel: DATA_STREAMS_TIME_PARAM_KEY,
            settlementDelay: ETH_USD_SETTLEMENT_DELAY,
            isPremium: false
        });
        // TODO: set price adapter
        ethUsdMarketOrderConfiguration = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_MARKET,
            isEnabled: true,
            fee: DATA_STREAMS_SETTLEMENT_FEE,
            settlementStrategy: mockDefaultMarketOrderSettlementStrategy,
            data: abi.encode(ethUsdMarketOrderConfigurationData)
        });

        // TODO: update limit order strategy and move the market's strategies definition to a separate file.
        // TODO: set price adapter
        ethUsdLimitOrderConfiguration = SettlementConfiguration.Data({
            strategyType: SettlementConfiguration.StrategyType.DATA_STREAMS_CUSTOM,
            isEnabled: true,
            fee: DATA_STREAMS_SETTLEMENT_FEE,
            settlementStrategy: mockDefaultMarketOrderSettlementStrategy,
            data: abi.encode(ethUsdMarketOrderConfigurationData)
        });

        btcUsdCustomOrderStrategies.push(btcUsdLimitOrderConfiguration);
        ethUsdCustomOrderStrategies.push(ethUsdLimitOrderConfiguration);
    }

    function createAccountAndDeposit(uint256 amount, address collateralType) internal returns (uint128 accountId) {
        accountId = perpsEngine.createPerpsAccount();
        perpsEngine.depositMargin(accountId, collateralType, amount);
    }

    function configureSystemParameters() internal {
        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: MAX_POSITIONS_PER_ACCOUNT,
            marketOrderMaxLifetime: MARKET_ORDER_MAX_LIFETIME,
            liquidationFeeUsdX18: LIQUIDATION_FEE_USD
        });
    }

    function createMarkets() internal {
        perpsEngine.createPerpMarket(
            IGlobalConfigurationModule.CreatePerpMarketParams({
                marketId: BTC_USD_MARKET_ID,
                name: BTC_USD_MARKET_NAME,
                symbol: BTC_USD_MARKET_SYMBOL,
                priceAdapter: address(mockPriceAdapters.mockBtcUsdPriceAdapter),
                initialMarginRateX18: BTC_USD_IMR,
                maintenanceMarginRateX18: BTC_USD_MMR,
                maxOpenInterest: BTC_USD_MAX_OI,
                maxFundingVelocity: BTC_USD_MAX_FUNDING_VELOCITY,
                skewScale: BTC_USD_SKEW_SCALE,
                minTradeSizeX18: BTC_USD_MIN_TRADE_SIZE,
                marketOrderConfiguration: btcUsdMarketOrderConfiguration,
                customTriggerStrategies: btcUsdCustomOrderStrategies,
                orderFees: btcUsdOrderFees
            })
        );

        perpsEngine.createPerpMarket(
            IGlobalConfigurationModule.CreatePerpMarketParams({
                marketId: ETH_USD_MARKET_ID,
                name: ETH_USD_MARKET_NAME,
                symbol: ETH_USD_MARKET_SYMBOL,
                priceAdapter: address(mockPriceAdapters.mockEthUsdPriceAdapter),
                initialMarginRateX18: ETH_USD_IMR,
                maintenanceMarginRateX18: ETH_USD_MMR,
                maxOpenInterest: ETH_USD_MAX_OI,
                maxFundingVelocity: ETH_USD_MAX_FUNDING_VELOCITY,
                skewScale: ETH_USD_SKEW_SCALE,
                minTradeSizeX18: ETH_USD_MIN_TRADE_SIZE,
                marketOrderConfiguration: ethUsdMarketOrderConfiguration,
                customTriggerStrategies: ethUsdCustomOrderStrategies,
                orderFees: ethUsdOrderFees
            })
        );
    }

    function getPrice(MockPriceFeed priceFeed) internal view returns (UD60x18) {
        uint8 decimals = priceFeed.decimals();
        (, int256 answer,,,) = priceFeed.latestRoundData();

        return ud60x18(uint256(answer) * 10 ** (SYSTEM_DECIMALS - decimals));
    }

    function getMockedSignedReport(
        string memory streamId,
        uint256 price,
        bool isPremium
    )
        internal
        view
        returns (bytes memory mockedSignedReport)
    {
        // TODO: We need to check at the perps engine level if the report's stream id is the market's one.
        bytes32 mockStreamIdBytes32 = bytes32(uint256(keccak256(abi.encodePacked(streamId))));
        bytes memory mockedReportData;

        if (isPremium) {
            PremiumReport memory premiumReport = PremiumReport({
                feedId: mockStreamIdBytes32,
                validFromTimestamp: uint32(block.timestamp),
                observationsTimestamp: uint32(block.timestamp),
                nativeFee: 0,
                linkFee: 0,
                expiresAt: uint32(block.timestamp + MOCK_DATA_STREAMS_EXPIRATION_DELAY),
                price: int192(int256(price)),
                bid: int192(int256(price)),
                ask: int192(int256(price))
            });

            mockedReportData = abi.encode(premiumReport);
        } else {
            BasicReport memory basicReport = BasicReport({
                feedId: mockStreamIdBytes32,
                validFromTimestamp: uint32(block.timestamp),
                observationsTimestamp: uint32(block.timestamp),
                nativeFee: 0,
                linkFee: 0,
                expiresAt: uint32(block.timestamp + MOCK_DATA_STREAMS_EXPIRATION_DELAY),
                price: int192(int256(price))
            });

            mockedReportData = abi.encode(basicReport);
        }

        bytes32[3] memory mockedSignatures;
        mockedSignatures[0] = bytes32(uint256(keccak256(abi.encodePacked("mockedSignature1"))));
        mockedSignatures[1] = bytes32(uint256(keccak256(abi.encodePacked("mockedSignature2"))));
        mockedSignatures[2] = bytes32(uint256(keccak256(abi.encodePacked("mockedSignature3"))));

        mockedSignedReport = abi.encode(mockedSignatures, mockedReportData);
    }

    struct FuzzOrderSizeDeltaParams {
        uint128 accountId;
        uint128 marketId;
        uint128 settlementId;
        UD60x18 initialMarginRate;
        UD60x18 marginValueUsd;
        UD60x18 maxOpenInterest;
        UD60x18 minTradeSize;
        UD60x18 price;
        bool isLong;
    }

    struct FuzzOrderSizeDeltaContext {
        int128 sizeDeltaPrePriceImpact;
        int128 sizeDeltaAbs;
        UD60x18 fuzzedSizeDeltaAbs;
        UD60x18 sizeDeltaWithPriceImpact;
        UD60x18 totalOrderFeeInSize;
    }

    function fuzzOrderSizeDelta(FuzzOrderSizeDeltaParams memory params) internal view returns (int128 sizeDelta) {
        FuzzOrderSizeDeltaContext memory ctx;

        ctx.fuzzedSizeDeltaAbs = params.marginValueUsd.div(params.initialMarginRate).div(params.price);
        ctx.sizeDeltaAbs = Math.min(Math.max(ctx.fuzzedSizeDeltaAbs, params.minTradeSize), params.maxOpenInterest)
            .intoSD59x18().intoInt256().toInt128();
        ctx.sizeDeltaPrePriceImpact = params.isLong ? ctx.sizeDeltaAbs : -ctx.sizeDeltaAbs;

        (,,, SD59x18 orderFeeUsdX18, UD60x18 settlementFeeUsdX18, UD60x18 fillPriceX18) = perpsEngine.simulateTrade(
            params.accountId, params.marketId, params.settlementId, ctx.sizeDeltaPrePriceImpact
        );

        ctx.totalOrderFeeInSize = Math.divUp(orderFeeUsdX18.intoUD60x18().add(settlementFeeUsdX18), fillPriceX18);
        ctx.sizeDeltaWithPriceImpact = Math.min(
            (params.price.div(fillPriceX18).intoSD59x18().mul(sd59x18(ctx.sizeDeltaPrePriceImpact))).abs().intoUD60x18(
            ),
            params.maxOpenInterest
        );

        sizeDelta = (
            params.isLong
                ? Math.max(
                    ctx.sizeDeltaWithPriceImpact.intoSD59x18().sub(
                        ctx.totalOrderFeeInSize.intoSD59x18().div(params.initialMarginRate.intoSD59x18())
                    ),
                    params.minTradeSize.intoSD59x18()
                )
                : Math.min(
                    unary(ctx.sizeDeltaWithPriceImpact.intoSD59x18()).add(
                        ctx.totalOrderFeeInSize.intoSD59x18().div(params.initialMarginRate.intoSD59x18())
                    ),
                    unary(params.minTradeSize.intoSD59x18())
                )
        ).intoInt256().toInt128();

        console.log("Order Fuzzing: ");
        console.log(sd59x18(sizeDelta).abs().intoUD60x18().intoUint256());
        console.log(params.minTradeSize.intoUint256());
    }

    function mockSettleMarketOrder(uint128 accountId, uint128 marketId, bytes memory extraData) internal {
        address marketOrderUpkeep = marketOrderUpkeeps[marketId];

        perpsEngine.settleMarketOrder(accountId, marketId, marketOrderUpkeep, extraData);
    }
}
