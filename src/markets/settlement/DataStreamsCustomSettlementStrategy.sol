// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IFeeManager, FeeAsset } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { ChainlinkUtil } from "@zaros/external/chainlink/ChainlinkUtil.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { ISettlementStrategy } from "./interfaces/ISettlementStrategy.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

abstract contract DataStreamsCustomSettlementStrategy is ISettlementStrategy, OwnableUpgradeable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Chainlink Data Streams Reports default decimals (both Basic and Premium).
    uint8 internal constant REPORT_PRICE_DECIMALS = 8;

    /// @notice ERC7201 storage location.
    bytes32 internal constant DATA_STREAMS_SETTLEMENT_STRATEGY_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.markets.settlement.DataStreamsCustomSettlementStrategy")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.DataStreamsCustomSettlementStrategy
    /// @param chainlinkVerifier The address of the Chainlink Verifier contract.
    /// @param perpsEngine The address of the PerpsEngine contract.
    /// @param keepers The set of registered keepers addresses.
    /// @param marketId The Zaros perp market id which is using this strategy.
    /// @param settlementId The Zaros perp market settlement strategy id linked to this contract.
    struct DataStreamsCustomSettlementStrategyStorage {
        IVerifierProxy chainlinkVerifier;
        PerpsEngine perpsEngine;
        EnumerableSet.AddressSet keepers;
        uint128 marketId;
        uint128 settlementId;
    }

    /// @notice Ensures that only a registered keeper is able to call a function.
    modifier onlyRegisteredKeeper() {
        DataStreamsCustomSettlementStrategyStorage storage self = _getDataStreamsCustomSettlementStrategyStorage();
        bool isValidSender = self.keepers.contains(msg.sender);

        if (!isValidSender) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    modifier onlyPerpsEngine() {
        DataStreamsCustomSettlementStrategyStorage storage self = _getDataStreamsCustomSettlementStrategyStorage();
        bool isSenderPerpsEngine = msg.sender == address(self.perpsEngine);

        if (!isSenderPerpsEngine) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    function getZarosSettlementConfiguration() external view returns (SettlementConfiguration.Data memory) {
        DataStreamsCustomSettlementStrategyStorage storage dataStreamsCustomSettlementStrategyStorage =
            _getDataStreamsCustomSettlementStrategyStorage();

        PerpsEngine perpsEngine = dataStreamsCustomSettlementStrategyStorage.perpsEngine;
        uint128 marketId = dataStreamsCustomSettlementStrategyStorage.marketId;
        uint128 settlementId = dataStreamsCustomSettlementStrategyStorage.settlementId;

        SettlementConfiguration.Data memory settlementConfiguration =
            perpsEngine.getSettlementConfiguration(marketId, settlementId);

        return settlementConfiguration;
    }

    function settle(bytes calldata signedReport, bytes calldata extraData) external virtual;

    /// @notice {DataStreamsCustomSettlementStrategy} UUPS initializer.
    function __DataStreamsCustomSettlementStrategy_init(
        IVerifierProxy chainlinkVerifier,
        PerpsEngine perpsEngine,
        address[] calldata keepers,
        uint128 marketId,
        uint128 settlementId
    )
        internal
        onlyInitializing
    {
        __Ownable_init(msg.sender);

        if (address(chainlinkVerifier) == address(0)) {
            revert Errors.ZeroInput("chainlinkVerifier");
        }

        if (address(perpsEngine) == address(0)) {
            revert Errors.ZeroInput("perpsEngine");
        }
        if (keepers.length == 0) {
            revert Errors.ZeroInput("keepers");
        }

        if (marketId == 0) {
            revert Errors.ZeroInput("marketId");
        }
        if (settlementId == 0) {
            revert Errors.ZeroInput("settlementId");
        }

        DataStreamsCustomSettlementStrategyStorage storage self = _getDataStreamsCustomSettlementStrategyStorage();

        self.chainlinkVerifier = chainlinkVerifier;
        self.perpsEngine = perpsEngine;
        self.marketId = marketId;
        self.settlementId = settlementId;

        for (uint256 i = 0; i < keepers.length; i++) {
            self.keepers.add(keepers[i]);
        }
    }

    function _getKeepers() internal view returns (address[] memory keepers) {
        DataStreamsCustomSettlementStrategyStorage storage self = _getDataStreamsCustomSettlementStrategyStorage();

        keepers = new address[](self.keepers.length());

        for (uint256 i = 0; i < self.keepers.length(); i++) {
            keepers[i] = self.keepers.at(i);
        }
    }

    function _getDataStreamsCustomSettlementStrategyStorage()
        internal
        pure
        returns (DataStreamsCustomSettlementStrategyStorage storage self)
    {
        bytes32 slot = DATA_STREAMS_SETTLEMENT_STRATEGY_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    function _prepareDataStreamsSettlement(bytes memory signedReport) internal returns (PerpsEngine, bytes memory) {
        DataStreamsCustomSettlementStrategyStorage storage dataStreamsCustomSettlementStrategyStorage =
            _getDataStreamsCustomSettlementStrategyStorage();
        (IVerifierProxy chainlinkVerifier, PerpsEngine perpsEngine) = (
            IVerifierProxy(dataStreamsCustomSettlementStrategyStorage.chainlinkVerifier),
            dataStreamsCustomSettlementStrategyStorage.perpsEngine
        );

        bytes memory reportData = ChainlinkUtil.getReportData(signedReport);
        FeeAsset memory fee = ChainlinkUtil.getEthVericationFee(chainlinkVerifier, reportData);

        bytes memory verifiedReportData = ChainlinkUtil.verifyReport(chainlinkVerifier, fee, signedReport);

        return (perpsEngine, verifiedReportData);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
