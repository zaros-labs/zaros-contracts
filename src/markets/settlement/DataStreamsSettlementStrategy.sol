// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IFeeManager, FeeAsset } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { ChainlinkUtil } from "@zaros/external/chainlink/ChainlinkUtil.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

abstract contract DataStreamsSettlementStrategy is OwnableUpgradeable, UUPSUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Chainlink Data Streams Reports default decimals (both Basic and Premium).
    uint8 internal constant REPORT_PRICE_DECIMALS = 8;

    /// @notice ERC7201 storage location.
    bytes32 internal constant DATA_STREAMS_SETTLEMENT_STRATEGY_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.markets.settlement.DataStreamsSettlementStrategy")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.DataStreamsSettlementStrategy
    /// @param chainlinkVerifier The address of the Chainlink Verifier contract.
    /// @param perpsEngine The address of the PerpsEngine contract.
    /// @param keepers The set of registered keepers addresses.
    struct DataStreamsSettlementStrategyStorage {
        IVerifierProxy chainlinkVerifier;
        PerpsEngine perpsEngine;
        EnumerableSet.AddressSet keepers;
    }

    /// @notice Ensures that only a registered keeper is able to call a function.
    modifier onlyRegisteredKeeper() {
        DataStreamsSettlementStrategyStorage storage self = _getDataStreamsSettlementStrategyStorage();
        bool isValidSender = self.keepers.contains(msg.sender);

        if (!isValidSender) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    modifier onlyPerpsEngine() {
        DataStreamsSettlementStrategyStorage storage self = _getDataStreamsSettlementStrategyStorage();
        bool isSenderPerpsEngine = msg.sender == address(self.perpsEngine);

        if (!isSenderPerpsEngine) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    function settle(bytes calldata signedReport, ISettlementModule.SettlementPayload[] calldata payloads) external;

    /// @notice {DataStreamsSettlementStrategy} UUPS initializer.
    function __DataStreamsSettlementStrategy_init(
        IVerifierProxy chainlinkVerifier,
        PerpsEngine perpsEngine,
        address[] calldata keepers
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

        DataStreamsSettlementStrategyStorage storage self = _getDataStreamsSettlementStrategyStorage();

        self.chainlinkVerifier = chainlinkVerifier;
        self.perpsEngine = perpsEngine;

        for (uint256 i = 0; i < keepers.length; i++) {
            self.keepers.add(keepers[i]);
        }
    }

    function _getDataStreamsSettlementStrategyStorage()
        internal
        pure
        returns (DataStreamsSettlementStrategyStorage storage self)
    {
        bytes32 slot = DATA_STREAMS_SETTLEMENT_STRATEGY_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    function _prepareDataStreamsSettlement(bytes memory signedReport) internal returns (PerpsEngine, bytes memory) {
        DataStreamsSettlementStrategyStorage storage dataStreamsSettlementStrategyStorage =
            _getDataStreamsSettlementStrategyStorage();
        (IVerifierProxy chainlinkVerifier, PerpsEngine perpsEngine) = (
            IVerifierProxy(dataStreamsSettlementStrategyStorage.chainlinkVerifier),
            dataStreamsSettlementStrategyStorage.perpsEngine
        );

        bytes memory reportData = ChainlinkUtil.getReportData(signedReport);
        FeeAsset memory fee = ChainlinkUtil.getEthVericationFee(chainlinkVerifier, reportData);

        bytes memory verifiedReportData = ChainlinkUtil.verifyReport(chainlinkVerifier, fee, signedReport);

        return (perpsEngine, verifiedReportData);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
