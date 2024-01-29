// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IFeeManager } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { BasicReport, PremiumReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { CreatePerpMarketParams } from "@zaros/markets/perps/interfaces/IGlobalConfigurationModule.sol";
import { OrderFees } from "@zaros/markets/perps/storage/OrderFees.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { Base_Test } from "test/Base.t.sol";
import { MockChainlinkFeeManager } from "test/mocks/MockChainlinkFeeManager.sol";
import { MockChainlinkVerifier } from "test/mocks/MockChainlinkVerifier.sol";
import { MockPriceFeed } from "test/mocks/MockPriceFeed.sol";

// PRB Math dependencies
import { sd59x18 } from "@prb-math/SD59x18.sol";
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract Base_Integration_Shared_Test is Base_Test {
    address internal mockChainlinkFeeManager;
    address internal mockChainlinkVerifier;

    /// @dev TODO: think about forking tests
    address internal mockDefaultMarketOrderSettlementStrategy = vm.addr({ privateKey: 0x04 });

    /// @dev BTC / USD market configuration variables.
    SettlementConfiguration.DataStreamsMarketStrategy internal btcUsdMarketOrderConfigurationData;
    SettlementConfiguration.Data internal btcUsdMarketOrderConfiguration;
    // TODO: update limit order strategy and move the market's strategies definition to a separate file.
    SettlementConfiguration.Data internal btcUsdLimitOrderConfiguration;

    SettlementConfiguration.Data[] internal btcUsdCustomTriggerStrategies;

    OrderFees.Data internal btcUsdOrderFees;

    /// @dev ETH / USD market configuration variables.
    SettlementConfiguration.DataStreamsMarketStrategy internal ethUsdMarketOrderConfigurationData;
    SettlementConfiguration.Data internal ethUsdMarketOrderConfiguration;
    // TODO: update limit order strategy and move the market's strategies definition to a separate file.
    SettlementConfiguration.Data internal ethUsdLimitOrderConfiguration;

    SettlementConfiguration.Data[] internal ethUsdCustomTriggerStrategies;

    OrderFees.Data internal ethUsdOrderFees;

    function setUp() public virtual override {
        Base_Test.setUp();

        mockChainlinkFeeManager = address(new MockChainlinkFeeManager());
        mockChainlinkVerifier = address(new MockChainlinkVerifier(IFeeManager(mockChainlinkFeeManager)));

        /// @dev BTC / USD market configuration variables.
        btcUsdMarketOrderConfigurationData = SettlementConfiguration.DataStreamsMarketStrategy({
            chainlinkVerifier: IVerifierProxy(mockChainlinkVerifier),
            streamId: MOCK_ETH_USD_STREAM_ID,
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

        btcUsdOrderFees = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

        /// @dev ETH / USD market configuration variables.
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

        ethUsdOrderFees = OrderFees.Data({ makerFee: 0.04e18, takerFee: 0.08e18 });

        btcUsdCustomTriggerStrategies.push(btcUsdLimitOrderConfiguration);
        ethUsdCustomTriggerStrategies.push(ethUsdLimitOrderConfiguration);
    }

    function createAccountAndDeposit(uint256 amount, address collateralType) internal returns (uint128 accountId) {
        accountId = perpsEngine.createPerpsAccount();
        perpsEngine.depositMargin(accountId, collateralType, amount);
    }

    function configureSystemParameters() internal {
        perpsEngine.configureSystemParameters({
            maxPositionsPerAccount: MAX_POSITIONS_PER_ACCOUNT,
            marketOrderMaxLifetime: MARKET_ORDER_MAX_LIFETIME
        });
    }

    function createMarkets() internal {
        perpsEngine.createPerpMarket(
            CreatePerpMarketParams({
                marketId: BTC_USD_MARKET_ID,
                name: BTC_USD_MARKET_NAME,
                symbol: BTC_USD_MARKET_SYMBOL,
                priceAdapter: address(mockPriceAdapters.mockBtcUsdPriceAdapter),
                minInitialMarginRateX18: BTC_USD_MIN_IMR,
                maintenanceMarginRateX18: BTC_USD_MMR,
                maxOpenInterest: BTC_USD_MAX_OI,
                skewScale: BTC_USD_SKEW_SCALE,
                maxFundingVelocity: BTC_USD_MAX_FUNDING_VELOCITY,
                marketOrderConfiguration: btcUsdMarketOrderConfiguration,
                customTriggerStrategies: btcUsdCustomTriggerStrategies,
                orderFees: btcUsdOrderFees
            })
        );

        perpsEngine.createPerpMarket(
            CreatePerpMarketParams({
                marketId: ETH_USD_MARKET_ID,
                name: ETH_USD_MARKET_NAME,
                symbol: ETH_USD_MARKET_SYMBOL,
                priceAdapter: address(mockPriceAdapters.mockEthUsdPriceAdapter),
                minInitialMarginRateX18: ETH_USD_MIN_IMR,
                maintenanceMarginRateX18: ETH_USD_MMR,
                maxOpenInterest: ETH_USD_MAX_OI,
                skewScale: ETH_USD_SKEW_SCALE,
                maxFundingVelocity: ETH_USD_MAX_FUNDING_VELOCITY,
                marketOrderConfiguration: ethUsdMarketOrderConfiguration,
                customTriggerStrategies: ethUsdCustomTriggerStrategies,
                orderFees: ethUsdOrderFees
            })
        );
    }

    function getPrice(MockPriceFeed priceFeed) internal view returns (UD60x18) {
        uint8 decimals = priceFeed.decimals();
        (, int256 answer,,,) = priceFeed.latestRoundData();

        return ud60x18(uint256(answer) * 10 ** (DEFAULT_DECIMALS - decimals));
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

    function fuzzMarketOrderSizeDelta(
        uint256 initialMarginRate,
        uint256 marginValueUsd,
        bool isLong
    )
        internal
        pure
        returns (int128 sizeDelta)
    {
        int128 sizeDeltaAbs = int128(
            ud60x18(initialMarginRate).div(ud60x18(marginValueUsd)).div(ud60x18(MOCK_ETH_USD_PRICE)).intoSD59x18()
                .intoInt256()
        );
        sizeDelta = isLong ? sizeDeltaAbs : -sizeDeltaAbs;
    }

    function mockSettleMarketOrder(uint128 accountId, uint128 marketId, bytes memory extraData) internal {
        perpsEngine.settleMarketOrder(accountId, marketId, extraData);
    }
}
