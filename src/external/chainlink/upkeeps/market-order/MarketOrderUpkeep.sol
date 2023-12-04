// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { IFeeManager, FeeAsset } from "../../interfaces/IFeeManager.sol";
import { ILogAutomation, Log as AutomationLog } from "../../interfaces/ILogAutomation.sol";
import { IStreamsLookupCompatible, BasicReport } from "../../interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "../../interfaces/IVerifierProxy.sol";
import { ChainlinkUtil } from "../../ChainlinkUtil.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { Order } from "@zaros/markets/perps/storage/Order.sol";
import { SettlementStrategy } from "@zaros/markets/perps/storage/SettlementStrategy.sol";

// Open Zeppelin dependencies
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

contract MarketOrderUpkeep is ILogAutomation, IStreamsLookupCompatible, UUPSUpgradeable, OwnableUpgradeable {
    using SafeCast for uint256;

    /// @notice ERC7201 storage location.
    bytes32 internal constant MARKET_ORDER_UPKEEP_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.MarketOrderUpkeep")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.MarketOrderUpkeep
    /// @param chainlinkVerifier The address of the Chainlink Verifier contract.
    /// @param forwarder The address of the Upkeep forwarder contract.
    /// @param perpsEngine The address of the PerpsEngine contract.
    struct MarketOrderUpkeepStorage {
        address chainlinkVerifier;
        address forwarder;
        PerpsEngine perpsEngine;
    }

    /// @notice {MarketOrderUpkeep} UUPS initializer.
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

        MarketOrderUpkeepStorage storage self = _getMarketOrderUpkeepStorage();

        self.chainlinkVerifier = chainlinkVerifier;
        self.forwarder = forwarder;
        self.perpsEngine = perpsEngine;

        __Ownable_init(initialOwner);
    }

    /// @notice Ensures that only the Upkeep's forwarder contract can call a function.
    modifier onlyForwarder() {
        address forwarder = _getMarketOrderUpkeepStorage().forwarder;
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
        MarketOrderUpkeepStorage storage self = _getMarketOrderUpkeepStorage();

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
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        MarketOrderUpkeepStorage storage self = _getMarketOrderUpkeepStorage();
        PerpsEngine perpsEngine = self.perpsEngine;

        (uint128 accountId, uint128 marketId) = (uint256(log.topics[2]).toUint128(), uint256(log.topics[3]).toUint128());
        (Order.Market memory marketOrder) = abi.decode(log.data, (Order.Market));
        SettlementStrategy.Data memory settlementStrategy = perpsEngine.marketOrderStrategy(marketId);

        SettlementStrategy.DataStreamsMarketStrategy memory marketOrderStrategy =
            abi.decode(settlementStrategy.strategyData, (SettlementStrategy.DataStreamsMarketStrategy));

        string[] memory streams = new string[](1);
        streams[0] = string(abi.encodePacked(marketOrderStrategy.streamId));
        uint256 settlementTimestamp = marketOrder.timestamp + marketOrderStrategy.settlementDelay;
        bytes memory extraData = abi.encode(accountId, marketId);

        revert StreamsLookup(
            marketOrderStrategy.feedLabel, streams, marketOrderStrategy.queryLabel, settlementTimestamp, extraData
        );
    }

    /// TODO: compare gas optimization pre-loading variables here vs in performUpkeep. Remember of Arbitrum's l1 gas
    /// cost (calldata is the most expensive place).
    /// @inheritdoc IStreamsLookupCompatible
    function checkCallback(
        bytes[] calldata values,
        bytes calldata extraData
    )
        external
        pure
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        bytes memory signedReport = values[0];

        upkeepNeeded = true;
        performData = abi.encode(signedReport, extraData);
    }

    /// @inheritdoc ILogAutomation
    function performUpkeep(bytes calldata performData) external onlyForwarder {
        (bytes memory signedReport, uint128 accountId, uint128 marketId) =
            abi.decode(performData, (bytes, uint128, uint128));

        MarketOrderUpkeepStorage storage self = _getMarketOrderUpkeepStorage();
        (IVerifierProxy chainlinkVerifier, PerpsEngine perpsEngine) =
            (IVerifierProxy(self.chainlinkVerifier), self.perpsEngine);

        bytes memory reportData = ChainlinkUtil.getReportData(signedReport);
        FeeAsset memory fee = ChainlinkUtil.getEthVericationFee(chainlinkVerifier, reportData);

        bytes memory verifiedReportData = ChainlinkUtil.verifyReport(chainlinkVerifier, fee, signedReport);

        perpsEngine.settleMarketOrder(accountId, marketId, verifiedReportData);
    }

    function _getMarketOrderUpkeepStorage() internal pure returns (MarketOrderUpkeepStorage storage self) {
        bytes32 slot = MARKET_ORDER_UPKEEP_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
