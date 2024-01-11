// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { BasicReport, PremiumReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IFeeManager, FeeAsset } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { ChainlinkUtil } from "@zaros/external/chainlink/ChainlinkUtil.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { OracleUtil } from "@zaros/utils/OracleUtil.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

// TODO: Check if a given settlement configuration is enabled.
// TODO: Move OracleUtil to ChainlinkUtil.
/// @notice Settlement strategies supported by the protocol.
library SettlementConfiguration {
    using SafeCast for int256;

    /// @notice Constant base domain used to access a given SettlementConfiguration's storage slot.
    string internal constant SETTLEMENT_STRATEGY_DOMAIN = "fi.zaros.markets.PerpMarket.SettlementConfiguration";
    /// @notice The default strategy id for a given market's market orders settlementConfiguration.
    uint128 internal constant MARKET_ORDER_SETTLEMENT_ID = 0;

    /// @notice Strategies IDs supported.
    /// @param DATA_STREAMS_MARKET The strategy ID that uses basic or premium reports from CL Data Streams to
    /// settle market orders.
    /// @param DATA_STREAMS_CUSTOM The strategy ID that uses basic or premium reports from CL Data Streams to
    /// settle any sort of custom order.
    enum StrategyType {
        DATA_STREAMS_MARKET,
        DATA_STREAMS_CUSTOM
    }

    /// @notice The {SettlementConfiguration} namespace storage structure.
    /// @param strategyType The strategy id active.
    /// @param isEnabled Whether the strategy is enabled or not. May be used to pause trading in a market.
    /// @param fee The settlement cost in USD charged from the trader.
    /// @param settlementStrategy The address of the configured SettlementStrategy contract.
    /// @param priceAdapter The price adapter contract, which stores onchain and outputs the market's index price.
    /// @param data Data structure required for the settlement strategy, varies for each settlementConfiguration.
    struct Data {
        StrategyType strategyType;
        bool isEnabled;
        uint80 fee;
        address settlementStrategy;
        address priceAdapter;
        bytes data;
    }

    /// @notice Data structure used by the {DATA_STREAMS} settlementConfiguration.
    /// @param streamId The Chainlink Data Streams stream id.
    /// @param feedLabel The Chainlink Data Streams feed label.
    /// @param queryLabel The Chainlink Data Streams query label.
    /// @param settlementDelay The delay in seconds to wait for the settlement report.
    struct DataStreamsMarketStrategy {
        IVerifierProxy chainlinkVerifier;
        string streamId;
        string feedLabel;
        string queryLabel;
        uint248 settlementDelay;
        bool isPremium;
    }

    struct DataStreamsCustomStrategy {
        IVerifierProxy chainlinkVerifier;
        string streamId;
        string feedLabel;
        string queryLabel;
        bool isPremium;
    }

    /// @dev The market order strategy id is always 0.
    function load(
        uint128 marketId,
        uint128 settlementId
    )
        internal
        pure
        returns (Data storage settlementConfiguration)
    {
        bytes32 slot = keccak256(abi.encode(SETTLEMENT_STRATEGY_DOMAIN, marketId, settlementId));
        assembly {
            settlementConfiguration.slot := slot
        }
    }

    function create(uint128 marketId, uint128 settlementId, Data memory settlementConfiguration) internal {
        Data storage self = load(marketId, settlementId);

        self.strategyType = settlementConfiguration.strategyType;
        self.isEnabled = settlementConfiguration.isEnabled;
        self.fee = settlementConfiguration.fee;
        self.settlementStrategy = settlementConfiguration.settlementStrategy;
        self.data = settlementConfiguration.data;
    }

    // TODO: Call a Zaros-deployed price adaptar contract instead of calling CL AggregatorV3 interface.
    // TODO: By having a custom price adapter, we can e.g sync a price adapter with a settlement strategy contract to
    // deploy custom index markets.
    function getIndexPrice(Data storage self) internal view returns (UD60x18 indexPrice) {
        address priceAdapter = self.priceAdapter;
        if (priceAdapter == address(0)) {
            revert Errors.PriceAdapterNotDefined();
        }

        indexPrice = OracleUtil.getPrice(IAggregatorV3(priceAdapter));
    }

    /// @notice Returns the settlement index price for a given order based on the configured strategy.
    /// @param self The {SettlementConfiguration} storage pointer.
    /// @param verifiedExtraData The verified report data.
    /// @param isBuyOrder Whether the top-level order is a buy or sell order.
    function getIndexPrice(
        Data storage self,
        bytes memory verifiedExtraData,
        bool isBuyOrder
    )
        internal
        view
        returns (UD60x18 price)
    {
        if (self.strategyType == StrategyType.DATA_STREAMS_MARKET) {
            DataStreamsMarketStrategy memory dataStreamsMarketStrategy =
                abi.decode(self.data, (DataStreamsMarketStrategy));

            price = getDataStreamsReportPrice(verifiedExtraData, dataStreamsMarketStrategy.isPremium, isBuyOrder);
        } else if (self.strategyType == StrategyType.DATA_STREAMS_CUSTOM) {
            DataStreamsCustomStrategy memory dataStreamsCustomStrategy =
                abi.decode(self.data, (DataStreamsCustomStrategy));

            price = getDataStreamsReportPrice(verifiedExtraData, dataStreamsCustomStrategy.isPremium, isBuyOrder);
        } else {
            revert Errors.InvalidSettlementStrategyType(uint8(self.strategyType));
        }
    }

    /// @notice Returns the UD60x18 price from a verified report based on its type and whether the top-level order is
    /// a buy or sell order.
    /// @param verifiedExtraData The verified report data.
    /// @param isPremium Whether the report is a premium or basic report.
    /// @param isBuyOrder Whether the top-level order is a buy or sell order.
    function getDataStreamsReportPrice(
        bytes memory verifiedExtraData,
        bool isPremium,
        bool isBuyOrder
    )
        internal
        pure
        returns (UD60x18 price)
    {
        if (isPremium) {
            PremiumReport memory premiumReport = abi.decode(verifiedExtraData, (PremiumReport));

            price = isBuyOrder
                ? ud60x18(int256(premiumReport.ask).toUint256())
                : ud60x18(int256(premiumReport.bid).toUint256());
        } else {
            BasicReport memory basicReport = abi.decode(verifiedExtraData, (BasicReport));

            price = ud60x18(int256(basicReport.price).toUint256());
        }
    }

    // TODO: Implement
    function requireDataStreamsReportIsValid(
        string memory settlementStreamId,
        bytes memory verifiedReportData,
        bool isPremium
    )
        internal
    {
        // bytes32 settlementStreamIdHash = keccak256(abi.encodePacked(settlementStreamId));
        // bytes32 reportStreamIdHash;
        // bytes32 reportStreamId;
        // if (isPremium) {
        //     PremiumReport memory premiumReport = abi.decode(verifiedReportData, (PremiumReport));

        //     reportStreamId = premiumReport.feedId;
        //     reportStreamIdHash = keccak256(abi.encodePacked(premiumReport.feedId));
        // } else {
        //     BasicReport memory basicReport = abi.decode(verifiedReportData, (BasicReport));

        //     reportStreamId = basicReport.feedId;
        //     reportStreamIdHash = keccak256(abi.encodePacked(basicReport.feedId));
        // }

        // if (settlementStreamIdHash != reportStreamIdHash) {
        //     revert Errors.InvalidDataStreamReport(settlementStreamId, reportStreamId);
        // }
    }

    function verifyExtraData(
        Data storage self,
        bytes memory extraData
    )
        internal
        returns (bytes memory verifiedExtraData)
    {
        if (self.strategyType == StrategyType.DATA_STREAMS_MARKET) {
            DataStreamsMarketStrategy memory dataStreamsMarketStrategy =
                abi.decode(self.data, (DataStreamsMarketStrategy));
            verifiedExtraData = verifyDataStreamsReport(dataStreamsMarketStrategy, extraData);

            requireDataStreamsReportIsValid(
                dataStreamsMarketStrategy.streamId, verifiedExtraData, dataStreamsMarketStrategy.isPremium
            );
        } else if (self.strategyType == StrategyType.DATA_STREAMS_CUSTOM) {
            DataStreamsCustomStrategy memory dataStreamsCustomStrategy =
                abi.decode(self.data, (DataStreamsCustomStrategy));
            verifiedExtraData = verifyDataStreamsReport(dataStreamsCustomStrategy, extraData);

            requireDataStreamsReportIsValid(
                dataStreamsCustomStrategy.streamId, verifiedExtraData, dataStreamsCustomStrategy.isPremium
            );
        } else {
            revert Errors.InvalidSettlementStrategyType(uint8(self.strategyType));
        }
    }

    function verifyDataStreamsReport(
        DataStreamsMarketStrategy memory settlementStrategy,
        bytes memory signedReport
    )
        internal
        returns (bytes memory verifiedReportData)
    {
        IVerifierProxy chainlinkVerifier = settlementStrategy.chainlinkVerifier;

        verifiedReportData = verifyDataStreamsReport(chainlinkVerifier, signedReport);
    }

    function verifyDataStreamsReport(
        DataStreamsCustomStrategy memory settlementStrategy,
        bytes memory signedReport
    )
        internal
        returns (bytes memory verifiedReportData)
    {
        IVerifierProxy chainlinkVerifier = settlementStrategy.chainlinkVerifier;

        verifiedReportData = verifyDataStreamsReport(chainlinkVerifier, signedReport);
    }

    function verifyDataStreamsReport(
        IVerifierProxy chainlinkVerifier,
        bytes memory signedReport
    )
        internal
        returns (bytes memory verifiedReportData)
    {
        bytes memory reportData = ChainlinkUtil.getReportData(signedReport);
        FeeAsset memory fee = ChainlinkUtil.getEthVericationFee(chainlinkVerifier, reportData);

        verifiedReportData = ChainlinkUtil.verifyReport(chainlinkVerifier, fee, signedReport);
    }
}
