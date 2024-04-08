// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IAggregatorV3 } from "@zaros/external/chainlink/interfaces/IAggregatorV3.sol";
import { BasicReport, PremiumReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IFeeManager, FeeAsset } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { ChainlinkUtil } from "@zaros/external/chainlink/ChainlinkUtil.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { ChainlinkUtil } from "@zaros/external/chainlink/ChainlinkUtil.sol";

// Open Zeppelin dependencies
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

/// @notice Settlement strategies supported by the protocol.
library SettlementConfiguration {
    using SafeCast for int256;

    /// @notice Constant base domain used to access a given SettlementConfiguration's storage slot.
    string internal constant SETTLEMENT_STRATEGY_DOMAIN = "fi.zaros.markets.PerpMarket.SettlementConfiguration";
    /// @notice The default strategy id for a given market's market orders settlementConfiguration.
    uint128 internal constant MARKET_ORDER_CONFIGURATION_ID = 0;
    /// @notice The default strategy id for a given market's limit orders settlementConfiguration.
    uint128 internal constant LIMIT_ORDER_CONFIGURATION_ID = 1;
    /// @notice The default strategy id for a given market's OCO orders settlementConfiguration.
    uint128 internal constant OCO_ORDER_CONFIGURATION_ID = 2;

    /// @notice Strategies IDs supported.
    /// @param DATA_STREAMS_MARKET The strategy ID that uses basic or premium reports from CL Data Streams to
    /// settle market orders.
    /// @param DATA_STREAMS_CUSTOM The strategy ID that uses basic or premium reports from CL Data Streams to
    /// settle any sort of custom order.
    enum Strategy {
        DATA_STREAMS_MARKET,
        DATA_STREAMS_CUSTOM
    }

    /// @notice The {SettlementConfiguration} namespace storage structure.
    /// @param strategy The strategy id active.
    /// @param isEnabled Whether the strategy is enabled or not. May be used to pause trading in a market.
    /// @param fee The settlement cost in USD charged from the trader.
    /// @param keeper The address of the keeper that executes trades.
    /// @param data Data structure required for the settlement configuration, varies for each settlementConfiguration.
    struct Data {
        Strategy strategy;
        bool isEnabled;
        uint80 fee;
        address keeper;
        bytes data;
    }

    // TODO: Review if we should use settlementDelay or not
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

    modifier onlyEnabledSettlement(Data storage self) {
        if (!self.isEnabled) {
            revert Errors.SettlementDisabled();
        }
        _;
    }

    /// @dev The market order strategy id is always 0.
    function load(
        uint128 marketId,
        uint128 settlementConfigurationId
    )
        internal
        pure
        returns (Data storage settlementConfiguration)
    {
        bytes32 slot = keccak256(abi.encode(SETTLEMENT_STRATEGY_DOMAIN, marketId, settlementConfigurationId));
        assembly {
            settlementConfiguration.slot := slot
        }
    }

    function update(
        uint128 marketId,
        uint128 settlementConfigurationId,
        Data memory settlementConfiguration
    )
        internal
    {
        Data storage self = load(marketId, settlementConfigurationId);

        self.strategy = settlementConfiguration.strategy;
        self.isEnabled = settlementConfiguration.isEnabled;
        self.fee = settlementConfiguration.fee;
        self.keeper = settlementConfiguration.keeper;
        self.data = settlementConfiguration.data;
    }

    /// @notice Returns the settlement index price for a given order based on the configured strategy.
    /// @param self The {SettlementConfiguration} storage pointer.
    /// @param verifiedPriceData The verified report data.
    /// @param isBuyOrder Whether the top-level order is a buy or sell order.
    function getFillPrice(
        Data storage self,
        bytes memory verifiedPriceData,
        bool isBuyOrder
    )
        internal
        view
        returns (UD60x18 price)
    {
        if (self.strategy == Strategy.DATA_STREAMS_MARKET) {
            DataStreamsMarketStrategy memory dataStreamsMarketStrategy =
                abi.decode(self.data, (DataStreamsMarketStrategy));

            price = getDataStreamsReportPrice(verifiedPriceData, dataStreamsMarketStrategy.isPremium, isBuyOrder);
        } else if (self.strategy == Strategy.DATA_STREAMS_CUSTOM) {
            DataStreamsCustomStrategy memory dataStreamsCustomStrategy =
                abi.decode(self.data, (DataStreamsCustomStrategy));

            price = getDataStreamsReportPrice(verifiedPriceData, dataStreamsCustomStrategy.isPremium, isBuyOrder);
        } else {
            revert Errors.InvalidSettlementConfiguration(uint8(self.strategy));
        }
    }

    /// @notice Returns the UD60x18 price from a verified report based on its type and whether the top-level order is
    /// a buy or sell order.
    /// @param verifiedPriceData The verified report data.
    /// @param isPremium Whether the report is a premium or basic report.
    /// @param isBuyOrder Whether the top-level order is a buy or sell order.
    function getDataStreamsReportPrice(
        bytes memory verifiedPriceData,
        bool isPremium,
        bool isBuyOrder
    )
        internal
        pure
        returns (UD60x18 price)
    {
        if (isPremium) {
            PremiumReport memory premiumReport = abi.decode(verifiedPriceData, (PremiumReport));

            price = isBuyOrder
                ? ud60x18(int256(premiumReport.ask).toUint256())
                : ud60x18(int256(premiumReport.bid).toUint256());
        } else {
            BasicReport memory basicReport = abi.decode(verifiedPriceData, (BasicReport));

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

    function verifyPriceData(
        Data storage self,
        bytes memory extraData
    )
        internal
        returns (bytes memory verifiedPriceData)
    {
        if (self.strategy == Strategy.DATA_STREAMS_MARKET) {
            DataStreamsMarketStrategy memory dataStreamsMarketStrategy =
                abi.decode(self.data, (DataStreamsMarketStrategy));
            verifiedPriceData = verifyDataStreamsReport(dataStreamsMarketStrategy, extraData);

            requireDataStreamsReportIsValid(
                dataStreamsMarketStrategy.streamId, verifiedPriceData, dataStreamsMarketStrategy.isPremium
            );
        } else if (self.strategy == Strategy.DATA_STREAMS_CUSTOM) {
            DataStreamsCustomStrategy memory dataStreamsCustomStrategy =
                abi.decode(self.data, (DataStreamsCustomStrategy));
            verifiedPriceData = verifyDataStreamsReport(dataStreamsCustomStrategy, extraData);

            requireDataStreamsReportIsValid(
                dataStreamsCustomStrategy.streamId, verifiedPriceData, dataStreamsCustomStrategy.isPremium
            );
        } else {
            revert Errors.InvalidSettlementConfiguration(uint8(self.strategy));
        }
    }

    function verifyDataStreamsReport(
        DataStreamsMarketStrategy memory keeper,
        bytes memory signedReport
    )
        internal
        returns (bytes memory verifiedReportData)
    {
        IVerifierProxy chainlinkVerifier = keeper.chainlinkVerifier;

        verifiedReportData = verifyDataStreamsReport(chainlinkVerifier, signedReport);
    }

    function verifyDataStreamsReport(
        DataStreamsCustomStrategy memory keeper,
        bytes memory signedReport
    )
        internal
        returns (bytes memory verifiedReportData)
    {
        IVerifierProxy chainlinkVerifier = keeper.chainlinkVerifier;

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
