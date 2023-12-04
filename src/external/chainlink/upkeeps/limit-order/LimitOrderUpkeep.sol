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

    event LogCreateLimitOrder(uint128 accountId, uint256 orderId, uint128 price, int128 sizeDelta);

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
        PerpsEngine perpsEngine;
        uint128 nextOrderId;
        uint128 marketId;
        string dataStreamsFeedParamKey;
        string dataStreamsTimeParamKey;
        string streamId;
        EnumerableSet.UintSet limitOrdersIds;
    }

    /// @notice {LimitOrderUpkeep} UUPS initializer.
    function initialize(
        address chainlinkVerifier,
        address forwarder,
        PerpsEngine perpsEngine,
        uint128 marketId,
        string calldata dataStreamsFeedParamKey,
        string calldata dataStreamsTimeParamKey,
        string calldata streamId
    )
        external
        initializer
    {
        __Ownable_init(msg.sender);

        if (chainlinkVerifier == address(0)) {
            revert Errors.ZeroInput("chainlinkVerifier");
        }
        if (forwarder == address(0)) {
            revert Errors.ZeroInput("forwarder");
        }
        if (address(perpsEngine) == address(0)) {
            revert Errors.ZeroInput("perpsEngine");
        }
        if (marketId == 0) {
            revert Errors.ZeroInput("marketId");
        }
        if (bytes(dataStreamsFeedParamKey).length == 0) {
            revert Errors.ZeroInput("dataStreamsFeedParamKey");
        }
        if (bytes(dataStreamsTimeParamKey).length == 0) {
            revert Errors.ZeroInput("dataStreamsTimeParamKey");
        }
        if (bytes(streamId).length == 0) {
            revert Errors.ZeroInput("streamId");
        }

        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        self.chainlinkVerifier = chainlinkVerifier;
        self.forwarder = forwarder;
        self.perpsEngine = perpsEngine;
        self.marketId = marketId;
        self.dataStreamsFeedParamKey = dataStreamsFeedParamKey;
        self.dataStreamsTimeParamKey = dataStreamsTimeParamKey;
        self.streamId = streamId;
    }

    function getConfig()
        external
        view
        returns (
            address upkeepOwner,
            address chainlinkVerifier,
            address forwarder,
            address perpsEngine,
            uint128 marketId,
            string memory dataStreamsFeedParamKey,
            string memory dataStreamsTimeParamKey,
            string memory streamId
        )
    {
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();

        upkeepOwner = owner();
        chainlinkVerifier = self.chainlinkVerifier;
        forwarder = self.forwarder;
        perpsEngine = address(self.perpsEngine);
        marketId = self.marketId;
        dataStreamsFeedParamKey = self.dataStreamsFeedParamKey;
        dataStreamsTimeParamKey = self.dataStreamsTimeParamKey;
        streamId = self.streamId;
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

        uint256 amountOfOrders = self.limitOrdersIds.length() > upperBound ? upperBound : self.limitOrdersIds.length();

        if (amountOfOrders == 0) {
            return (upkeepNeeded, performData);
        }

        LimitOrder.Data[] memory limitOrders = new LimitOrder.Data[](amountOfOrders);

        for (uint256 i = lowerBound; i < amountOfOrders; i++) {
            uint256 orderId = self.limitOrdersIds.at(i);
            limitOrders[i] = LimitOrder.load(orderId);
        }

        string[] memory feedsParam = new string[](1);
        feedsParam[0] = self.streamId;
        bytes memory extraData = abi.encode(limitOrders);

        revert StreamsLookup(
            self.dataStreamsFeedParamKey, feedsParam, self.dataStreamsTimeParamKey, block.timestamp, extraData
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
        LimitOrder.Data[] memory fillableOrders = new LimitOrder.Data[](0);

        bytes memory signedReport = values[0];
        BasicReport memory report = abi.decode(ChainlinkUtil.getReportData(signedReport), (BasicReport));
        (LimitOrder.Data[] memory limitOrders) = abi.decode(extraData, (LimitOrder.Data[]));

        for (uint256 i = 0; i < limitOrders.length; i++) {
            LimitOrder.Data memory limitOrder = limitOrders[i];
            // TODO: store decimals per market?
            UD60x18 orderPrice = ud60x18(limitOrder.price);
            UD60x18 reportPrice = ChainlinkUtil.convertReportPriceToUd60x18(report.price, 8);

            bool isOrderFillable = (
                limitOrder.sizeDelta > 0 && reportPrice.lte(orderPrice)
                    || (limitOrder.sizeDelta < 0 && reportPrice.gte(orderPrice))
            );

            if (isOrderFillable) {
                fillableOrders[fillableOrders.length] = limitOrder;
            }
        }

        if (fillableOrders.length > 0) {
            upkeepNeeded = true;
            performData = abi.encode(signedReport, fillableOrders);
        }
    }

    function createLimitOrder(uint128 accountId, uint128 marketId, uint128 price, int128 sizeDelta) external {
        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();
        bool isSenderAuthorized = self.perpsEngine.isAuthorized(accountId, msg.sender);

        if (!isSenderAuthorized) {
            revert Errors.Unauthorized(msg.sender);
        }

        uint256 orderId = ++self.nextOrderId;

        // There should never be a duplicate order id, but let's make sure anyway.
        assert(!self.limitOrdersIds.contains(orderId));
        self.limitOrdersIds.add(orderId);

        LimitOrder.create({ accountId: accountId, orderId: orderId, price: price, sizeDelta: sizeDelta });

        emit LogCreateLimitOrder(accountId, orderId, price, sizeDelta);
    }

    function performUpkeep(bytes calldata performData) external override {
        (bytes memory signedReport, LimitOrder.Data[] memory fillableOrders) =
            abi.decode(performData, (bytes, LimitOrder.Data[]));

        LimitOrderUpkeepStorage storage self = _getLimitOrderUpkeepStorage();
        (IVerifierProxy chainlinkVerifier, PerpsEngine perpsEngine, uint128 marketId) =
            (IVerifierProxy(self.chainlinkVerifier), self.perpsEngine, self.marketId);

        bytes memory reportData = ChainlinkUtil.getReportData(signedReport);
        FeeAsset memory fee = ChainlinkUtil.getEthVericationFee(chainlinkVerifier, reportData);

        bytes memory verifiedReportData = ChainlinkUtil.verifyReport(chainlinkVerifier, fee, signedReport);

        // perpsEngine.settleCustomTriggers();
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
