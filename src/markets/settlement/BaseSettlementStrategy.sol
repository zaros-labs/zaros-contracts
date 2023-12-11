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
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

abstract contract BaseSettlementStrategy is OwnableUpgradeable, UUPSUpgradeable {
    /// @notice Chainlink Data Streams Reports default decimals (both Basic and Premium).
    uint8 internal constant REPORT_PRICE_DECIMALS = 8;

    /// @notice ERC7201 storage location.
    bytes32 internal constant BASE_SETTLEMENT_STRATEGY_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.BaseSettlementStrategy")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.BaseSettlementStrategy
    /// @param chainlinkVerifier The address of the Chainlink Verifier contract.
    /// @param forwarder The address of the Upkeep forwarder contract.
    /// @param perpsEngine The address of the PerpsEngine contract.
    struct BaseSettlementStrategyStorage {
        address chainlinkVerifier;
        address forwarder;
        PerpsEngine perpsEngine;
    }

    /// @notice Ensures that only a registered keeper is able to call a function.
    modifier onlyRegisteredKeeper() {
        BaseSettlementStrategyStorage storage self = _getBaseSettlementStrategyStorage();
        bool isValidSender = self.keepers.contains(msg.sender);

        if (!isValidSender) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    modifier onlyPerpsEngine() {
        BaseSettlementStrategyStorage storage self = _getBaseSettlementStrategyStorage();
        bool isSenderPerpsEngine = msg.sender == address(self.perpsEngine);

        if (!isSenderPerpsEngine) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice {BaseSettlementStrategy} UUPS initializer.
    function __BaseSettlementStrategy_init(
        address chainlinkVerifier,
        PerpsEngine perpsEngine,
        address[] calldata keepers
    )
        internal
        onlyInitializing
    {
        __Ownable_init(msg.sender);

        if (chainlinkVerifier == address(0)) {
            revert Errors.ZeroInput("chainlinkVerifier");
        }

        if (address(perpsEngine) == address(0)) {
            revert Errors.ZeroInput("perpsEngine");
        }
        if (keepers.length == 0) {
            revert Errors.ZeroInput("keepers");
        }

        BaseSettlementStrategyStorage storage self = _getBaseSettlementStrategyStorage();

        self.chainlinkVerifier = chainlinkVerifier;
        self.perpsEngine = perpsEngine;

        for (uint256 i = 0; i < keepers.length; i++) {
            self.keepers.add(keepers[i]);
        }
    }

    function _getBaseSettlementStrategyStorage() internal pure returns (BaseSettlementStrategyStorage storage self) {
        bytes32 slot = BASE_SETTLEMENT_STRATEGY_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    function _preparePerformData(
        uint128 marketId,
        bytes memory performData
    )
        internal
        returns (PerpsEngine, ISettlementModule.SettlementPayload[] memory, bytes memory)
    {
        (bytes memory signedReport, ISettlementModule.SettlementPayload[] memory payloads) =
            abi.decode(performData, (bytes, ISettlementModule.SettlementPayload[]));

        BaseSettlementStrategyStorage storage baseSettlementStrategyStorage = _getBaseSettlementStrategyStorage();
        (IVerifierProxy chainlinkVerifier, PerpsEngine perpsEngine) =
            (IVerifierProxy(baseSettlementStrategyStorage.chainlinkVerifier), baseSettlementStrategyStorage.perpsEngine);

        bytes memory reportData = ChainlinkUtil.getReportData(signedReport);
        FeeAsset memory fee = ChainlinkUtil.getEthVericationFee(chainlinkVerifier, reportData);

        bytes memory verifiedReportData = ChainlinkUtil.verifyReport(chainlinkVerifier, fee, signedReport);

        return (perpsEngine, payloads, verifiedReportData);
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
