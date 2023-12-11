// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { IVerifierProxy } from "@zaros/external/chainlink/interfaces/IVerifierProxy.sol";
import { PerpsEngine } from "@zaros/markets/perps/PerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { ISettlementStrategy } from "./interfaces/ISettlementStrategy.sol";
import { DataStreamsSettlementStrategy } from "./DataStreamsSettlementStrategy.sol";
import { OcoOrder } from "./storage/OcoOrder.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

contract OcoOrderSettlementStrategy is DataStreamsSettlementStrategy, ISettlementStrategy {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeCast for uint256;

    enum Actions { UPDATE_OCO_ORDER }

    event LogCreateOcoOrder(
        address indexed sender, uint128 accountId, OcoOrder.TakeProfit takeProfit, OcoOrder.StopLoss stopLoss
    );

    /// @notice ERC7201 storage location.
    bytes32 internal constant OCO_ORDER_SETTLEMENT_STRATEGY_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.markets.settlement.OcoOrderSettlementStrategy")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.markets.settlement.OcoOrderSettlementStrategy
    struct OcoOrderSettlementStrategyStorage {
        EnumerableSet.UintSet accountsWithActiveOrders;
        mapping(uint128 accountId => OcoOrder.Data) ocoOrderOfAccount;
    }

    /// @notice {OcoOrderSettlementStrategy} UUPS initializer.
    function initialize(
        IVerifierProxy chainlinkVerifier,
        PerpsEngine perpsEngine,
        address[] calldata keepers,
        uint128 marketId,
        uint128 settlementId
    )
        external
        initializer
    {
        __DataStreamsSettlementStrategy_init(chainlinkVerifier, perpsEngine, keepers, marketId, settlementId);
    }

    function getConfig()
        public
        view
        returns (
            address settlementStrategyOwner,
            address chainlinkVerifier,
            address[] memory keepers,
            address perpsEngine,
            uint128 marketId,
            uint128 settlementId
        )
    {
        DataStreamsSettlementStrategyStorage storage dataStreamsSettlementStrategyStorage =
            _getDataStreamsSettlementStrategyStorage();

        settlementStrategyOwner = owner();
        chainlinkVerifier = address(dataStreamsSettlementStrategyStorage.chainlinkVerifier);
        keepers = _getKeepers();
        perpsEngine = address(dataStreamsSettlementStrategyStorage.perpsEngine);
        marketId = dataStreamsSettlementStrategyStorage.marketId;
        settlementId = dataStreamsSettlementStrategyStorage.settlementId;
    }

    function getOcoOrders(uint256 lowerBound, uint256 upperBound) external view returns (OcoOrder.Data[] memory) {
        OcoOrderSettlementStrategyStorage storage self = _getOcoOrderSettlementStrategyStorage();

        uint256 amountOfOrders =
            self.accountsWithActiveOrders.length() > upperBound ? upperBound : self.accountsWithActiveOrders.length();
        OcoOrder.Data[] memory ocoOrders = new OcoOrder.Data[](amountOfOrders);

        if (amountOfOrders == 0) {
            return ocoOrders;
        }

        for (uint256 i = lowerBound; i < amountOfOrders; i++) {
            uint128 accountId = self.accountsWithActiveOrders.at(i).toUint128();
            ocoOrders[i] = self.ocoOrderOfAccount[accountId];
        }

        return ocoOrders;
    }

    function beforeSettlement(ISettlementModule.SettlementPayload calldata payload) external override { }

    function afterSettlement() external override onlyPerpsEngine { }

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

    function settle(
        bytes calldata signedReport,
        ISettlementModule.SettlementPayload[] calldata payloads
    )
        external
        override
        onlyRegisteredKeeper
    {
        DataStreamsSettlementStrategyStorage storage dataStreamsSettlementStrategyStorage =
            _getDataStreamsSettlementStrategyStorage();
        (uint128 marketId, uint128 settlementId) =
            (dataStreamsSettlementStrategyStorage.marketId, dataStreamsSettlementStrategyStorage.settlementId);
        (PerpsEngine perpsEngine, bytes memory verifiedReportData) = _prepareDataStreamsSettlement(signedReport);

        perpsEngine.settleCustomTriggers(marketId, settlementId, payloads, verifiedReportData);
    }

    function _getOcoOrderSettlementStrategyStorage()
        internal
        pure
        returns (OcoOrderSettlementStrategyStorage storage self)
    {
        bytes32 slot = OCO_ORDER_SETTLEMENT_STRATEGY_LOCATION;

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
        OcoOrderSettlementStrategyStorage storage self = _getOcoOrderSettlementStrategyStorage();

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
