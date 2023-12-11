// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { IAutomationCompatible } from "../../interfaces/IAutomationCompatible.sol";
import { IFeeManager, FeeAsset } from "../../interfaces/IFeeManager.sol";
import { ILogAutomation, Log as AutomationLog } from "../../interfaces/ILogAutomation.sol";
import { IStreamsLookupCompatible, BasicReport, PremiumReport } from "../../interfaces/IStreamsLookupCompatible.sol";
import { IVerifierProxy } from "../../interfaces/IVerifierProxy.sol";
import { BaseUpkeep } from "../BaseUpkeep.sol";
import { ChainlinkUtil } from "../../ChainlinkUtil.sol";
import { OcoOrder } from "./storage/OcoOrder.sol";
import { Errors } from "@zaros/utils/Errors.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
// import { SD59x18, sd59x18 } from "@prb-math/SD59x18.sol";

contract OcoOrderUpkeep is IAutomationCompatible, IStreamsLookupCompatible, BaseUpkeep {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeCast for uint256;

    enum Actions { UPDATE_OCO_ORDER }

    event LogCreateOcoOrder(
        address indexed sender, uint128 accountId, OcoOrder.TakeProfit takeProfit, OcoOrder.StopLoss stopLoss
    );

    /// @notice ERC7201 storage location.
    bytes32 internal constant OCO_ORDER_UPKEEP_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.external.chainlink.upkeeps.OcoOrderUpkeep")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.external.chainlink.OcoOrderUpkeep
    struct OcoOrderUpkeepStorage {
        uint128 marketId;
        uint128 settlementId;
        EnumerableSet.UintSet accountsWithActiveOrders;
        mapping(uint128 accountId => OcoOrder.Data) ocoOrderOfAccount;
    }

    /// @notice {OcoOrderUpkeep} UUPS initializer.
    function initialize(
        address chainlinkVerifier,
        address forwarder,
        PerpsEngine perpsEngine,
        uint128 marketId,
        uint128 settlementId
    )
        external
        initializer
    {
        __BaseUpkeep_init(chainlinkVerifier, forwarder, perpsEngine);

        if (marketId == 0) {
            revert Errors.ZeroInput("marketId");
        }
        if (settlementId == 0) {
            revert Errors.ZeroInput("settlementId");
        }

        OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();

        self.marketId = marketId;
        self.settlementId = settlementId;
    }

    function getConfig()
        public
        view
        returns (
            address upkeepOwner,
            address chainlinkVerifier,
            address forwarder,
            address perpsEngine,
            uint128 marketId,
            uint128 settlementId
        )
    {
        BaseUpkeepStorage storage baseUpkeepStorage = _getBaseUpkeepStorage();
        OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();

        upkeepOwner = owner();
        chainlinkVerifier = baseUpkeepStorage.chainlinkVerifier;
        forwarder = baseUpkeepStorage.forwarder;
        perpsEngine = address(baseUpkeepStorage.perpsEngine);
        marketId = self.marketId;
        settlementId = self.settlementId;
    }

    function checkUpkeep(bytes calldata checkData)
        external
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        (uint256 checkLowerBound, uint256 checkUpperBound, uint256 performLowerBound, uint256 performUpperBound) =
            abi.decode(checkData, (uint256, uint256, uint256, uint256));

        if (checkLowerBound > checkUpperBound || performLowerBound > performUpperBound) {
            revert Errors.InvalidBounds();
        }

        BaseUpkeepStorage storage baseUpkeepStorage = _getBaseUpkeepStorage();
        OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();
        PerpsEngine perpsEngine = baseUpkeepStorage.perpsEngine;

        uint256 amountOfOrders = self.accountsWithActiveOrders.length() > checkUpperBound
            ? checkUpperBound
            : self.accountsWithActiveOrders.length();

        if (amountOfOrders == 0) {
            return (upkeepNeeded, performData);
        }

        OcoOrder.Data[] memory ocoOrders = new OcoOrder.Data[](amountOfOrders);

        for (uint256 i = checkLowerBound; i < amountOfOrders; i++) {
            uint128 accountId = self.accountsWithActiveOrders.at(i).toUint128();
            ocoOrders[i] = self.ocoOrderOfAccount[accountId];
        }

        SettlementConfiguration.Data memory settlementStrategy =
            perpsEngine.getSettlementStrategy(self.marketId, self.settlementId);
        SettlementConfiguration.DataStreamsCustomStrategy memory dataStreamsCustomStrategy =
            abi.decode(settlementStrategy.data, (SettlementConfiguration.DataStreamsCustomStrategy));

        string[] memory feedsParam = new string[](1);
        feedsParam[0] = dataStreamsCustomStrategy.streamId;
        bytes memory extraData =
            abi.encode(ocoOrders, performLowerBound, performUpperBound, dataStreamsCustomStrategy.isPremium);

        revert StreamsLookup(
            dataStreamsCustomStrategy.feedLabel,
            feedsParam,
            dataStreamsCustomStrategy.queryLabel,
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
        ISettlementModule.SettlementPayload[] memory payloads = new ISettlementModule.SettlementPayload[](0);

        (OcoOrder.Data[] memory ocoOrders, uint256 performLowerBound, uint256 performUpperBound, bool isPremiumReport) =
            abi.decode(extraData, (OcoOrder.Data[], uint256, uint256, bool));
        uint256 ordersToIterate = ocoOrders.length > performUpperBound ? performUpperBound : ocoOrders.length;

        bytes memory reportData = ChainlinkUtil.getReportData(values[0]);

        UD60x18 reportPrice = ChainlinkUtil.getReportPriceUd60x18(reportData, REPORT_PRICE_DECIMALS, isPremiumReport);

        for (uint256 i = performLowerBound; i < ordersToIterate; i++) {
            OcoOrder.TakeProfit memory takeProfit = ocoOrders[i].takeProfit;
            OcoOrder.StopLoss memory stopLoss = ocoOrders[i].stopLoss;

            bool isLongPosition = takeProfit.sizeDelta < 0 || stopLoss.sizeDelta < 0;

            bool isTpFillable = (
                isLongPosition ? ud60x18(takeProfit.price).gte(reportPrice) : ud60x18(takeProfit.price).lte(reportPrice)
            ) && takeProfit.price != 0;

            bool isStopLossFillable = (
                isLongPosition ? ud60x18(stopLoss.price).lte(reportPrice) : ud60x18(stopLoss.price).gte(reportPrice)
            ) && stopLoss.price != 0;

            if (isTpFillable || isStopLossFillable) {
                payloads[payloads.length] = ISettlementModule.SettlementPayload({
                    accountId: ocoOrders[i].accountId,
                    sizeDelta: isTpFillable ? takeProfit.sizeDelta : stopLoss.sizeDelta
                });
            }
        }

        if (payloads.length > 0) {
            upkeepNeeded = true;
            performData = abi.encode(values[0], payloads);
        }
    }

    function invoke(uint128 accountId, bytes calldata extraData) external override onlyPerpsEngine {
        (Actions action) = abi.decode(extraData[0:8], (Actions));

        if (action == Actions.UPDATE_OCO_ORDER) {
            (OcoOrder.TakeProfit memory takeProfit, OcoOrder.StopLoss memory stopLoss) =
                abi.decode(extraData[8:], (OcoOrder.TakeProfit, OcoOrder.StopLoss));

            _updateOcoOrder(accountId, takeProfit, stopLoss);
        } else {
            revert Errors.InvalidSettlementStrategyAction();
        }
    }

    function beforeSettlement(ISettlementModule.SettlementPayload calldata payload) external override { }

    function afterSettlement() external override onlyPerpsEngine { }

    function performUpkeep(bytes calldata performData) external override onlyForwarder {
        OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();
        (uint128 marketId, uint128 settlementId) = (self.marketId, self.settlementId);
        (
            PerpsEngine perpsEngine,
            ISettlementModule.SettlementPayload[] memory payloads,
            bytes memory verifiedReportData
        ) = _preparePerformData(marketId, performData);

        perpsEngine.settleCustomTriggers(marketId, settlementId, payloads, verifiedReportData);
    }

    function _getOcoOrderUpkeepStorage() internal pure returns (OcoOrderUpkeepStorage storage self) {
        bytes32 slot = OCO_ORDER_UPKEEP_LOCATION;

        assembly {
            self.slot := slot
        }
    }

    function _updateOcoOrder(
        uint128 accountId,
        OcoOrder.TakeProfit memory takeProfit,
        OcoOrder.StopLoss memory stopLoss
    )
        internal
    {
        OcoOrderUpkeepStorage storage self = _getOcoOrderUpkeepStorage();

        if (takeProfit.price != 0 && takeProfit.price < stopLoss.price) {
            revert Errors.InvalidOcoOrder();
        }

        bool isAccountWithNewOcoOrder =
            takeProfit.price != 0 || stopLoss.price != 0 && !self.accountsWithActiveOrders.contains(accountId);
        bool isAccountCancellingOcoOrder =
            takeProfit.price == 0 && stopLoss.price == 0 && self.accountsWithActiveOrders.contains(accountId);

        bool isLongPosition = takeProfit.sizeDelta < 0 || stopLoss.sizeDelta < 0;

        bool isValidOcoOrder = !isAccountCancellingOcoOrder && isLongPosition
            ? takeProfit.price > stopLoss.price
            : takeProfit.price < stopLoss.price;

        if (!isValidOcoOrder) {
            revert Errors.InvalidOcoOrder();
        }

        if (isAccountWithNewOcoOrder) {
            self.accountsWithActiveOrders.add(accountId);
        } else if (isAccountCancellingOcoOrder) {
            self.accountsWithActiveOrders.remove(accountId);
        }

        self.ocoOrderOfAccount[accountId] =
            OcoOrder.Data({ accountId: accountId, takeProfit: takeProfit, stopLoss: stopLoss });

        emit LogCreateOcoOrder(msg.sender, accountId, takeProfit, stopLoss);
    }
}
