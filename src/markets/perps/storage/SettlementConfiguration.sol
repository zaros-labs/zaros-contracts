// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { BasicReport, PremiumReport } from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { IFeeManager, FeeAsset } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { ChainlinkUtil } from "@zaros/external/chainlink/ChainlinkUtil.sol";
import { Errors } from "@zaros/utils/Errors.sol";

import "forge-std/console.sol";

/// @notice Settlement strategies supported by the protocol.
library SettlementConfiguration {
    /// @notice Constant base domain used to access a given SettlementConfiguration's storage slot.
    string internal constant SETTLEMENT_STRATEGY_DOMAIN = "fi.zaros.markets.PerpsMarket.SettlementConfiguration";
    /// @notice The default strategy id for a given market's market orders settlementConfiguration.
    uint128 internal constant MARKET_ORDER_SETTLEMENT_ID = 0;

    /// @notice Strategies IDs supported.
    /// @param DATA_STREAMS_MARKET The strategy ID that uses basic or premium reports from CL Data Streams to settle
    /// market orders.
    /// @param DATA_STREAMS_CUSTOM The strategy ID that uses basic or premium reports from CL Data Streams to settle any
    /// sort of custom order.
    enum StrategyType {
        DATA_STREAMS_MARKET,
        DATA_STREAMS_CUSTOM
    }

    /// @notice The {SettlementConfiguration} namespace storage structure.
    /// @param strategyType The strategy id active.
    /// @param isEnabled Whether the strategy is enabled or not. May be used to pause trading in a market.
    /// @param fee The settlement cost in USD charged from the trader.
    /// @param settlementStrategy The address of the configured SettlementStrategy contract.
    /// @param data Data structure required for the settlement strategy, varies for each settlementConfiguration.
    struct Data {
        StrategyType strategyType;
        bool isEnabled;
        uint80 fee;
        address settlementStrategy;
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
        bytes32 slot = keccak256(abi.encode(SETTLEMENT_STRATEGY_DOMAIN, marketId, settlementId));
        Data storage self = load(marketId, settlementId);

        self.strategyType = settlementConfiguration.strategyType;
        self.isEnabled = settlementConfiguration.isEnabled;
        self.fee = settlementConfiguration.fee;
        self.settlementStrategy = settlementConfiguration.settlementStrategy;
        self.data = settlementConfiguration.data;
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
