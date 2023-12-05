// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IAutomationCompatible } from "../../interfaces/IAutomationCompatible.sol";
import { IFeeManager, FeeAsset } from "../../interfaces/IFeeManager.sol";
import { ILogAutomation, Log as AutomationLog } from "../../interfaces/ILogAutomation.sol";
import { IStreamsLookupCompatible, BasicReport } from "../../interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "../../interfaces/IVerifierProxy.sol";
import { ChainlinkUtil } from "../../ChainlinkUtil.sol";
import { OcoOrder } from "./storage/OcoOrder.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementStrategy } from "@zaros/markets/perps/storage/SettlementStrategy.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

contract OcoOrderUpkeep is IAutomationCompatible, IStreamsLookupCompatible, UUPSUpgradeable, OwnableUpgradeable {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeCast for uint256;

    event LogCreateOcoOrder(
        address indexed sender, uint128 accountId, OcoOrder.TakeProfit takeProfit, OcoOrder.StopLoss stopLoss
    );

    /// @notice ERC7201 storage location.
    bytes32 internal constant OCO_ORDER_UPKEEP_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.OcoOrderUpkeep")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.OcoOrderUpkeep
    /// @param chainlinkVerifier The address of the Chainlink Verifier contract.
    /// @param forwarder The address of the Upkeep forwarder contract.
    /// @param perpsEngine The address of the PerpsEngine contract.
    struct OcoOrderUpkeepStorage {
        address chainlinkVerifier;
        address forwarder;
        PerpsEngine perpsEngine;
        uint128 marketId;
        uint128 strategyId;
        mapping(uint128 accountId => OcoOrder.Data) accountActiveOcoOrder;
    }

    /// @notice {OcoOrderUpkeep} UUPS initializer.
    function initialize(
        address chainlinkVerifier,
        address forwarder,
        PerpsEngine perpsEngine,
        uint128 marketId,
        uint128 strategyId
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
        if (strategyId == 0) {
            revert Errors.ZeroInput("strategyId");
        }

        OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();

        self.chainlinkVerifier = chainlinkVerifier;
        self.forwarder = forwarder;
        self.perpsEngine = perpsEngine;
        self.marketId = marketId;
        self.strategyId = strategyId;
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
            uint128 strategyId
        )
    {
        OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();

        upkeepOwner = owner();
        chainlinkVerifier = self.chainlinkVerifier;
        forwarder = self.forwarder;
        perpsEngine = address(self.perpsEngine);
        marketId = self.marketId;
        strategyId = self.strategyId;
    }

    function checkUpkeep(bytes calldata checkData)
        external
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // (uint256 lowerBound, uint256 upperBound) = abi.decode(checkData, (uint256, uint256));

        // if (lowerBound > upperBound) {
        //     revert Errors.InvalidBounds(lowerBound, upperBound);
        // }

        // OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();
        // PerpsEngine perpsEngine = self.perpsEngine;

        // uint256 amountOfOrders = self.ocoOrdersIds.length() > upperBound ? upperBound : self.ocoOrdersIds.length();

        // if (amountOfOrders == 0) {
        //     return (upkeepNeeded, performData);
        // }

        // OcoOrder.Data[] memory ocoOrders = new OcoOrder.Data[](amountOfOrders);

        // for (uint256 i = lowerBound; i < amountOfOrders; i++) {
        //     uint256 orderId = self.ocoOrdersIds.at(i);
        //     ocoOrders[i] = OcoOrder.load(orderId);
        // }

        // SettlementStrategy.Data memory settlementStrategy =
        //     perpsEngine.getSettlementStrategy(self.marketId, self.strategyId);
        // SettlementStrategy.DataStreamsCustomStrategy memory dataStreamsCustomStrategy =
        //     abi.decode(settlementStrategy.data, (SettlementStrategy.DataStreamsCustomStrategy));

        // string[] memory feedsParam = new string[](1);
        // feedsParam[0] = dataStreamsCustomStrategy.streamId;
        // bytes memory extraData = abi.encode(ocoOrders);

        // revert StreamsLookup(
        //     dataStreamsCustomStrategy.feedLabel,
        //     feedsParam,
        //     dataStreamsCustomStrategy.queryLabel,
        //     block.timestamp,
        //     extraData
        // );
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
        // OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();
        // ISettlementModule.SettlementPayload[] memory payloads = new ISettlementModule.SettlementPayload[](0);

        // bytes memory signedReport = values[0];
        // bytes memory reportData = ChainlinkUtil.getReportData(signedReport);
        // BasicReport memory report = abi.decode(reportData, (BasicReport));
        // (OcoOrder.Data[] memory ocoOrders) = abi.decode(extraData, (OcoOrder.Data[]));

        // for (uint256 i = 0; i < ocoOrders.length; i++) {
        //     OcoOrder.Data memory ocoOrder = ocoOrders[i];
        //     // TODO: store decimals per market?
        //     UD60x18 orderPrice = ud60x18(ocoOrder.price);
        //     UD60x18 reportPrice = ChainlinkUtil.convertReportPriceToUd60x18(report.price, 8);

        //     bool isOrderFillable = (
        //         ocoOrder.sizeDelta > 0 && reportPrice.lte(orderPrice)
        //             || (ocoOrder.sizeDelta < 0 && reportPrice.gte(orderPrice))
        //     );

        //     if (isOrderFillable) {
        //         payloads[payloads.length] = ISettlementModule.SettlementPayload({
        //             accountId: ocoOrder.accountId,
        //             sizeDelta: ocoOrder.sizeDelta
        //         });
        //     }
        // }

        // if (payloads.length > 0) {
        //     upkeepNeeded = true;
        //     performData = abi.encode(signedReport, payloads);
        // }
    }

    function updateOcoOrder(
        uint128 accountId,
        OcoOrder.TakeProfit calldata takeProfit,
        OcoOrder.StopLoss calldata stopLoss
    )
        external
    {
        OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();
        bool isSenderAuthorized = self.perpsEngine.isAuthorized(accountId, msg.sender);

        if (!isSenderAuthorized) {
            revert Errors.Unauthorized(msg.sender);
        }

        self.accountActiveOcoOrder[accountId] = OcoOrder.Data({ takeProfit: takeProfit, stopLoss: stopLoss });

        emit LogCreateOcoOrder(msg.sender, accountId, takeProfit, stopLoss);
    }

    function performUpkeep(bytes calldata performData) external override {
        // (bytes memory signedReport, ISettlementModule.SettlementPayload[] memory payloads) =
        //     abi.decode(performData, (bytes, ISettlementModule.SettlementPayload[]));

        // OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();
        // (IVerifierProxy chainlinkVerifier, PerpsEngine perpsEngine, uint128 marketId, uint128 strategyId) =
        //     (IVerifierProxy(self.chainlinkVerifier), self.perpsEngine, self.marketId, self.strategyId);

        // bytes memory reportData = ChainlinkUtil.getReportData(signedReport);
        // FeeAsset memory fee = ChainlinkUtil.getEthVericationFee(chainlinkVerifier, reportData);

        // bytes memory verifiedReportData = ChainlinkUtil.verifyReport(chainlinkVerifier, fee, signedReport);

        // perpsEngine.settleCustomTriggers(marketId, strategyId, payloads, verifiedReportData);
    }

    function _getOcoOrderUpkeepStorage() internal pure returns (OcoOrderUpkeepStorage storage self) {
        bytes32 slot = OCO_ORDER_UPKEEP_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address) internal override onlyOwner { }
}
