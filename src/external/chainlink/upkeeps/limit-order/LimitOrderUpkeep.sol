// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IAutomationCompatible } from "../../interfaces/IAutomationCompatible.sol";
import { IFeeManager, FeeAsset } from "../../interfaces/IFeeManager.sol";
import { ILogAutomation, Log as AutomationLog } from "../../interfaces/ILogAutomation.sol";
import { IStreamsLookupCompatible, BasicReport } from "../../interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "../../interfaces/IVerifierProxy.sol";
import { ChainlinkUtil } from "../../ChainlinkUtil.sol";
import { LimitOrder } from "./storage/LimitOrder.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { SettlementStrategy } from "@zaros/markets/perps/storage/SettlementStrategy.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract LimitOrderUpkeep is IAutomationCompatible, IStreamsLookupCompatible, UUPSUpgradeable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeCast for uint256;

    event LogCreateLimitOrder(uint128 marketId, uint128 accountId, uint256 orderId, uint128 price, int128 sizeDelta);

    /// @notice ERC7201 storage location.
    bytes32 internal constant LIMIT_ORDER_UPKEEP_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.LimitOrderUpkeep")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.LimitOrderUpkeep
    /// @param chainlinkVerifier The address of the Chainlink Verifier contract.
    /// @param forwarder The address of the Upkeep forwarder contract.
    /// @param perpsEngine The address of the PerpsEngine contract.
    struct LimitOrderUpkeepStorage {
        address chainlinkVerifier;
        address forwarder;
        string dataStreamsFeedParamKey;
        string dataStreamsTimeParamKey;
        PerpsEngine perpsEngine;
        mapping(uint128 marketId => bool) isMarketSupported;
        EnumerableSet.UintSet marketsWithActiveOrders;
        uint256 nextOrderId;
        EnumerableSet.UintSet limitOrdersIds;
    }

    /// @notice {LimitOrderUpkeep} UUPS initializer.
    function initialize(
        address initialOwner,
        address chainlinkVerifier,
        address forwarder,
        PerpsEngine perpsEngine,
        string calldata dataStreamsFeedParamKey,
        string calldata dataStreamsTimeParamKey
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
        if (bytes(dataStreamsFeedParamKey).length == 0) {
            revert Errors.ZeroInput("dataStreamsFeedParamKey");
        }
        if (bytes(dataStreamsTimeParamKey).length == 0) {
            revert Errors.ZeroInput("dataStreamsTimeParamKey");
        }

        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        self.chainlinkVerifier = chainlinkVerifier;
        self.forwarder = forwarder;
        self.perpsEngine = perpsEngine;
        self.dataStreamsFeedParamKey = dataStreamsFeedParamKey;
        self.dataStreamsTimeParamKey = dataStreamsTimeParamKey;

        __Ownable_init(initialOwner);
    }

    function getConfig()
        external
        view
        returns (address upkeepOwner, address chainlinkVerifier, address forwarder, address perpsEngine)
    {
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        upkeepOwner = owner();
        chainlinkVerifier = self.chainlinkVerifier;
        forwarder = self.forwarder;
        perpsEngine = address(self.perpsEngine);
    }

    function checkUpkeep(bytes calldata checkData)
        external
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        (uint256 lowerBound, uint256 upperBound) = abi.decode(checkData, (uint256, uint256));

        if (lowerBound > upperBound) {
            revert Errors.InvalidBounds(lowerBound, upperBound);
        }

        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();
        PerpsEngine perpsEngine = self.perpsEngine;
        uint256 amountOfPendingLimitOrders = self.limitOrdersIds.length();

        if (amountOfPendingLimitOrders == 0) {
            upkeepNeeded = false;
            performData = bytes("");

            return (upkeepNeeded, performData);
        }

        LimitOrder.Data[] memory pendingLimitOrders =
            new LimitOrder.Data[](amountOfPendingLimitOrders < upperBound ? amountOfPendingLimitOrders : upperBound);

        for (uint256 i = lowerBound; i < upperBound; i++) {
            uint256 orderId = self.limitOrdersIds.at(i);
            LimitOrder.Data memory limitOrder = LimitOrder.load(orderId);
            pendingLimitOrders[i] = limitOrder;
        }

        uint256 amountOfActiveMarkets = self.marketsWithActiveOrders.length();
        string[] memory limitOrdersStreamIds = new string[](amountOfActiveMarkets);

        for (uint256 i = 0; i < amountOfActiveMarkets; i++) {
            uint128 marketId = self.marketsWithActiveOrders.at(i).toUint128();
            SettlementStrategy.Data memory settlementStrategy = perpsEngine.settlementStrategy(marketId);
            SettlementStrategy.DataStreamsStrategy memory dataStreamsStrategy =
                abi.decode(settlementStrategy.strategyData, (SettlementStrategy.DataStreamsStrategy));
            limitOrdersStreamIds[i] = dataStreamsStrategy.streamId;
        }

        bytes memory extraData = abi.encode(pendingLimitOrders);

        revert StreamsLookup(
            self.dataStreamsFeedParamKey, limitOrdersStreamIds, self.dataStreamsTimeParamKey, block.timestamp, extraData
        );
    }

    function checkCallback(
        bytes[] calldata values,
        bytes calldata extraData
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        (bytes[] memory signedReportsArray, uint128 accountId, uint128 marketId) =
            abi.decode(performData, (bytes[], uint128, uint128));

        bytes memory signedReport = signedReportsArray[0];
        bytes memory reportData = ChainlinkUtil.getReportData(signedReport);
        // TODO: handle premium reports
        BasicReport memory report = abi.decode(reportData, (BasicReport));
    }

    function createLimitOrder(uint128 accountId, uint128 marketId, uint128 price, int128 sizeDelta) external {
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();
        bool isSenderAuthorized = self.perpsEngine.isAuthorized(accountId, msg.sender);

        if (!isSenderAuthorized) {
            revert Errors.Unauthorized(msg.sender);
        }

        if (!self.isMarketSupported[marketId]) {
            revert Errors.UnsupportedMarketId(marketId);
        }

        if (!self.marketsWithActiveOrders.contains(marketId)) {
            // we don't need to check the return value since we already checked if the market is in the set
            self.marketsWithActiveOrders.add(marketId);
        }

        // if (!self.accountsWithActiveOrders.contains(accountId)) {
        //     // we don't need to check the return value since we already checked if the account is in the set
        //     self.accountsWithActiveOrders.add(accountId);
        // }
        uint256 orderId = ++self.nextOrderId;

        // There should never be a duplicate order id, but let's make sure anyway.
        assert(!self.limitOrdersIds.contains(orderId));
        self.limitOrdersIds.add(orderId);

        LimitOrder.create({
            marketId: marketId,
            accountId: accountId,
            orderId: orderId,
            price: price,
            sizeDelta: sizeDelta
        });

        emit LogCreateLimitOrder(marketId, accountId, orderId, price, sizeDelta);
    }

    function configureSupportedMarkets(uint128[] calldata marketIds, bool[] calldata isSupported) external onlyOwner {
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        if (marketIds.length != isSupported.length) {
            revert Errors.ArrayLengthMismatch(marketIds.length, isSupported.length);
        }

        for (uint256 i = 0; i < marketIds.length; i++) {
            uint128 marketId = marketIds[i];
            bool isMarketSupported = isSupported[i];

            self.isMarketSupported[marketId] = isMarketSupported;
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        this;
    }

    function _getLimitOrderUpkeepStorage() internal pure returns (LimitOrderUpkeepStorage storage self) {
        bytes32 slot = LIMIT_ORDER_UPKEEP_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
