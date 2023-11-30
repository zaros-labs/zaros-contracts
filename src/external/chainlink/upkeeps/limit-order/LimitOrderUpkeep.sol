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

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

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
        mapping(string streamId => uint128) marketIdForStreamId;
        mapping(uint128 marketId => string) streamIdForMarketId;
        mapping(uint128 marketId => bool) isMarketEnabled;
        mapping(uint128 marketId => EnumerableSet.UintSet) limitOrdersIdsPerMarketId;
        EnumerableSet.UintSet marketsWithActiveOrders;
        uint256 nextOrderId;
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
        uint256 amountOfActiveMarkets = self.marketsWithActiveOrders.length();

        if (amountOfActiveMarkets == 0) {
            upkeepNeeded = false;
            performData = bytes("");

            return (upkeepNeeded, performData);
        }

        string[] memory activeMarketsStreamIds;

        for (uint256 i = 0; i < amountOfActiveMarkets; i++) {
            uint128 marketId = self.marketsWithActiveOrders.at(i).toUint128();
            string memory streamId = self.streamIdForMarketId[marketId];

            activeMarketsStreamIds[i] = streamId;
        }

        // bytes memory extraData = abi.encode(pendingLimitOrdersIdsPerMarketId);
        bytes memory extraData;

        revert StreamsLookup(
            self.dataStreamsFeedParamKey,
            activeMarketsStreamIds,
            self.dataStreamsTimeParamKey,
            block.timestamp,
            extraData
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
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();
        LimitOrder.Data[] memory inRangeOrders = new LimitOrder.Data[]();

        for (uint256 i = 0; i < values.length; i++) {
            BasicReport memory report = abi.decode(ChainlinkUtil.getReportData(values[i]), (BasicReport));
            uint128 marketId = self.marketIdForStreamId[report.feedId];
            uint256 amountOfOrders = self.limitOrdersIdsPerMarketId[marketId].length();

            for (uint256 j = 0; j < amountOfOrders; j++) {
                uint256 orderId = self.limitOrdersIdsPerMarketId[marketId].at(i);
                // TODO: store decimals per market?
                UD60x18 reportPrice = ChainlinkUtil.convertReportPriceToUd60x18(report.price, 8);
                LimitOrder.Data memory limitOrder = LimitOrder.load(orderId);
                bool isOrderInRange = (
                    limitOrder.sizeDelta > 0 && reportPrice.lte(ud60x18(limitOrder.price))
                        || (limitOrder.sizeDelta < 0 && reportPrice.gte(ud60x18(limitOrder.price)))
                );

                if (isOrderInRange) {
                    inRangeOrders[inRangeOrders.length] = limitOrder;
                }
            }
        }
    }

    function createLimitOrder(uint128 accountId, uint128 marketId, uint128 price, int128 sizeDelta) external {
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();
        bool isSenderAuthorized = self.perpsEngine.isAuthorized(accountId, msg.sender);

        if (!isSenderAuthorized) {
            revert Errors.Unauthorized(msg.sender);
        }

        if (!self.isMarketEnabled[marketId]) {
            revert Errors.DisabledMarketId(marketId);
        }

        if (!self.marketsWithActiveOrders.contains(marketId)) {
            // we don't need to check the return value since we already checked if the market is in the set
            self.marketsWithActiveOrders.add(marketId);
        }

        uint256 orderId = ++self.nextOrderId;

        // There should never be a duplicate order id, but let's make sure anyway.
        assert(!self.limitOrdersIdsPerMarketId[marketId].contains(orderId));
        self.limitOrdersIdsPerMarketId[marketId].add(orderId);

        string memory streamId = self.streamIdForMarketId[marketId];

        LimitOrder.create({
            marketId: marketId,
            accountId: accountId,
            orderId: orderId,
            price: price,
            sizeDelta: sizeDelta,
            streamId: streamId
        });

        emit LogCreateLimitOrder(marketId, accountId, orderId, price, sizeDelta);
    }

    function configureSupportedMarkets(
        uint128[] calldata marketIds,
        string[] calldata streamIds,
        bool[] calldata isEnabled
    )
        external
        onlyOwner
    {
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        if (marketIds.length != isEnabled.length) {
            revert Errors.ArrayLengthMismatch(marketIds.length, isEnabled.length);
        }

        for (uint256 i = 0; i < marketIds.length; i++) {
            uint128 marketId = marketIds[i];
            string memory streamId = streamIds[i];
            bool isMarketEnabled = isEnabled[i];

            if (isMarketEnabled && bytes(streamId).length == 0) {
                revert Errors.ZeroInput("streamId");
            }

            self.isMarketEnabled[marketId] = isMarketEnabled;
            self.marketIdForStreamId[streamId] = marketId;
            self.streamIdForMarketId[marketId] = streamId;
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
