// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IFeeManager, FeeAsset } from "@zaros/external/chainlink/interfaces/IFeeManager.sol";
import { ILogAutomation, Log as AutomationLog } from "@zaros/external/chainlink/interfaces/ILogAutomation.sol";
import {
    IStreamsLookupCompatible, BasicReport
} from "@zaros/external/chainlink/interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { Constants } from "@zaros/utils/Constants.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { Order } from "@zaros/markets/perps/storage/Order.sol";

// Open Zeppelin Upgradeable dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { SafeCastUpgradeable as SafeCast } from "@openzeppelin-upgradeable/utils/math/SafeCastUpgradeable.sol";

contract MarketOrderUpkeep is ILogAutomation, IStreamsLookupCompatible, UUPSUpgradeable, OwnableUpgradeable {
    using SafeCast for uint256;

    /// @notice The address of the Chainlink Verifier contract.
    IVerifierProxy public chainlinkVerifier;
    /// @notice The address of the Upkeep forwarder contract.
    address public forwarder;
    /// @notice The address of the PerpsEngine contract.
    PerpsEngine public perpsEngine;

    /// @notice {MarketOrderUpkeep} UUPS initializer.
    function initialize(
        IVerifierProxy _chainlinkVerifier,
        address _forwarder,
        PerpsEngine _perpsEngine
    )
        external
        initializer
    {
        if (address(_chainlinkVerifier) == address(0)) {
            revert Errors.ZeroInput("_chainlinkVerifier");
        }
        if (_forwarder == address(0)) {
            revert Errors.ZeroInput("_forwarder");
        }
        if (address(_perpsEngine) == address(0)) {
            revert Errors.ZeroInput("_perpsEngine");
        }

        chainlinkVerifier = _chainlinkVerifier;
        forwarder = _forwarder;
        perpsEngine = _perpsEngine;

        __Ownable_init();
    }

    /// @notice Ensures that only the Upkeep's forwarder contract can call a function.
    modifier onlyForwarder() {
        if (msg.sender != forwarder) {
            revert Errors.OnlyForwarder(msg.sender, forwarder);
        }
        _;
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
        (uint8 orderId, uint248 settlementTimestamp, bytes32 streamId) = abi.decode(log.data, (uint8, uint248, bytes32));

        string[] memory streams = new string[](1);
        streams[0] = string(abi.encodePacked(streamId));
        bytes memory extraData = abi.encode(accountId, marketId, orderId);

        revert StreamsLookup(
            Constants.DATA_STREAMS_FEED_LABEL,
            streams,
            Constants.DATA_STREAMS_QUERY_LABEL,
            settlementTimestamp,
            extraData
        );
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

        IFeeManager chainlinkFeeManager = IFeeManager(chainlinkVerifier.s_feeManager());
        // TODO: Store preferred fee token instead of querying i_nativeAddress?
        address feeTokenAddress = chainlinkFeeManager.i_nativeAddress();

        (uint256 accountId, uint128 marketId, uint8 orderId) = abi.decode(extraData, (uint256, uint128, uint8));

        upkeepNeeded = true;
        performData =
            abi.encode(signedReport, reportData, chainlinkFeeManager, feeTokenAddress, accountId, marketId, orderId);
    }

    /// @inheritdoc ILogAutomation
    function performUpkeep(bytes calldata performData) external onlyForwarder {
        (
            bytes memory signedReport,
            bytes memory reportData,
            IFeeManager chainlinkFeeManager,
            address feeTokenAddress,
            uint256 accountId,
            uint128 marketId,
            uint8 orderId
        ) = abi.decode(performData, (bytes, bytes, IFeeManager, address, uint256, uint128, uint8));

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

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
