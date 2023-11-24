// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IFeeManager, FeeAsset } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { ILogAutomation, Log as AutomationLog } from "@zaros/external/chainlink/interfaces/ILogAutomation.sol";
import {
    IStreamsLookupCompatible, BasicReport
} from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { Order } from "@zaros/markets/perps/storage/Order.sol";
import { SettlementStrategy } from "@zaros/markets/perps/storage/SettlementStrategy.sol";

// Open Zeppelin dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

contract BasicSettlementUpkeep is ILogAutomation, IStreamsLookupCompatible, UUPSUpgradeable, OwnableUpgradeable {
    using SafeCast for uint256;

    /// @notice keccak256(abi.encode(uint256(keccak256("example.main")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 internal constant SETTLEMENT_UPKEEP_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.BasicSettlementUpkeep")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.BasicSettlementUpkeep
    /// @param chainlinkVerifier The address of the Chainlink Verifier contract.
    /// @param forwarder The address of the Upkeep forwarder contract.
    /// @param perpsEngine The address of the PerpsEngine contract.
    struct BasicSettlementUpkeepStorage {
        address chainlinkVerifier;
        address forwarder;
        PerpsEngine perpsEngine;
    }

    /// @notice {BasicSettlementUpkeep} UUPS initializer.
    function initialize(
        address initialOwner,
        address chainlinkVerifier,
        address forwarder,
        PerpsEngine perpsEngine
    )
        external
        initializer
    {
        if (chainlinkVerifier == address(0)) {
            revert Errors.ZeroInput("chainlinkVerifier");
        }
        if (forwarder == address(0)) {
            revert Errors.ZeroInput("forwarder");
        }
        if (address(perpsEngine) == address(0)) {
            revert Errors.ZeroInput("perpsEngine");
        }

        BasicSettlementUpkeepStorage storage self = _getBasicSettlementUpkeepStorage();

        self.chainlinkVerifier = chainlinkVerifier;
        self.forwarder = forwarder;
        self.perpsEngine = perpsEngine;

        __Ownable_init(initialOwner);
    }

    /// @notice Ensures that only the Upkeep's forwarder contract can call a function.
    modifier onlyForwarder() {
        address forwarder = _getBasicSettlementUpkeepStorage().forwarder;
        if (msg.sender != forwarder) {
            revert Errors.OnlyForwarder(msg.sender, forwarder);
        }
        _;
    }

    function getConfig()
        external
        view
        returns (address upkeepOwner, address chainlinkVerifier, address forwarder, address perpsEngine)
    {
        BasicSettlementUpkeepStorage storage self = _getBasicSettlementUpkeepStorage();

        upkeepOwner = owner();
        chainlinkVerifier = self.chainlinkVerifier;
        forwarder = self.forwarder;
        perpsEngine = address(self.perpsEngine);
    }

    /// TODO: add check if upkeep is turned on (check contract's ETH funding)
    /// @inheritdoc ILogAutomation
    function checkLog(
        AutomationLog calldata log,
        bytes calldata checkData
    )
        external
        pure
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        (uint256 accountId, uint128 marketId) = (uint256(log.topics[2]), uint256(log.topics[3]).toUint128());
        (uint8 orderId, uint248 timestamp, SettlementStrategy.Data memory settlementStrategy) =
            abi.decode(log.data, (uint8, uint248, SettlementStrategy.Data));

        SettlementStrategy.DataStreamsBasicFeed memory strategy =
            abi.decode(settlementStrategy.strategyData, (SettlementStrategy.DataStreamsBasicFeed));

        string[] memory streams = new string[](1);
        streams[0] = string(abi.encodePacked(strategy.streamId));
        uint256 settlementTimestamp = timestamp + strategy.settlementDelay;
        bytes memory extraData = abi.encode(accountId, marketId, orderId);

        revert StreamsLookup(strategy.feedLabel, streams, strategy.queryLabel, settlementTimestamp, extraData);
    }

    /// @inheritdoc IStreamsLookupCompatible
    function checkCallback(
        bytes[] memory values,
        bytes memory extraData
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        bytes memory signedReport = values[0];
        bytes memory reportData = _getReportData(signedReport);

        BasicSettlementUpkeepStorage storage self = _getBasicSettlementUpkeepStorage();
        (IVerifierProxy chainlinkVerifier, PerpsEngine perpsEngine) =
            (IVerifierProxy(self.chainlinkVerifier), self.perpsEngine);

        IFeeManager chainlinkFeeManager = chainlinkVerifier.s_feeManager();
        // TODO: Store preferred fee token instead of querying i_nativeAddress?
        address feeTokenAddress = chainlinkFeeManager.i_nativeAddress();

        (uint256 accountId, uint128 marketId, uint8 orderId) = abi.decode(extraData, (uint256, uint128, uint8));

        upkeepNeeded = true;
        performData = abi.encode(
            signedReport,
            reportData,
            chainlinkVerifier,
            chainlinkFeeManager,
            perpsEngine,
            feeTokenAddress,
            accountId,
            marketId,
            orderId
        );
    }

    /// @inheritdoc ILogAutomation
    function performUpkeep(bytes calldata performData) external onlyForwarder {
        (
            bytes memory signedReport,
            bytes memory reportData,
            IVerifierProxy chainlinkVerifier,
            IFeeManager chainlinkFeeManager,
            PerpsEngine perpsEngine,
            address feeTokenAddress,
            uint256 accountId,
            uint128 marketId,
            uint8 orderId
        ) = abi.decode(
            performData, (bytes, bytes, IVerifierProxy, IFeeManager, PerpsEngine, address, uint256, uint128, uint8)
        );

        (FeeAsset memory fee,,) = chainlinkFeeManager.getFeeAndReward(address(this), reportData, feeTokenAddress);

        bytes memory verifiedReportData =
            chainlinkVerifier.verify{ value: fee.amount }(signedReport, abi.encode(fee.assetAddress));
        BasicReport memory verifiedReport = abi.decode(verifiedReportData, (BasicReport));

        perpsEngine.settleOrder(accountId, marketId, orderId, verifiedReport);
    }

    /// @notice Decodes the signedReport object and returns the report data only.
    function _getReportData(bytes memory signedReport) internal pure returns (bytes memory reportData) {
        (, reportData) = abi.decode(signedReport, (bytes32[3], bytes));
    }

    function _getBasicSettlementUpkeepStorage() internal pure returns (BasicSettlementUpkeepStorage storage self) {
        bytes32 slot = SETTLEMENT_UPKEEP_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
