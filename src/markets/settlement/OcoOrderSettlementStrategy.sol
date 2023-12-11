// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { ISettlementStrategy } from "./interfaces/ISettlementStrategy.sol";
import { DataStreamsSettlementStrategy } from "./DataStreamsSettlementStrategy.sol";
import { OcoOrder } from "./storage/OcoOrder.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";

contract OcoOrderSettlementStrategy is DataStreamsSettlementStrategy, ISettlementStrategy {
    using EnumerableSet for EnumerableSet.UintSet;

    enum Actions { UPDATE_OCO_ORDER }

    /// @notice ERC7201 storage location.
    bytes32 internal constant OCO_ORDER_SETTLEMENT_STRATEGY_LOCATION = keccak256(
        abi.encode(uint256(keccak256("fi.zaros.markets.settlement.OcoOrderSettlementStrategy")) - 1)
    ) & ~bytes32(uint256(0xff));

    /// @custom:storage-location erc7201:fi.zaros.markets.settlement.OcoOrderSettlementStrategy
    struct OcoOrderSettlementStrategyStorage {
        uint128 marketId;
        uint128 settlementId;
        EnumerableSet.UintSet accountsWithActiveOrders;
        mapping(uint128 accountId => OcoOrder.Data) ocoOrderOfAccount;
    }

    /// @notice {OcoOrderSettlementStrategy} UUPS initializer.
    function initialize(
        address chainlinkVerifier,
        PerpsEngine perpsEngine,
        address[] calldata keepers,
        uint128 marketId,
        uint128 settlementId
    )
        external
        initializer
    {
        __DataStreamsSettlementStrategy_init(chainlinkVerifier, perpsEngine, keepers);

        if (marketId == 0) {
            revert Errors.ZeroInput("marketId");
        }
        if (settlementId == 0) {
            revert Errors.ZeroInput("settlementId");
        }

        OcoOrderSettlementStrategyStorage storage self = _getOcoOrderSettlementStrategyStorage();

        self.marketId = marketId;
        self.settlementId = settlementId;
    }

    function getConfig()
        public
        view
        returns (
            address settlementStrategyOwner,
            address chainlinkVerifier,
            address forwarder,
            address perpsEngine,
            uint128 marketId,
            uint128 settlementId
        )
    {
        BaseUpkeepStorage storage baseUpkeepStorage = _getDataStreamsSettlementStrategyStorage();
        OcoOrderUpkeepStorage storage self = _getOcoOrderSettlementStrategyStorage();

        settlementStrategyOwner = owner();
        chainlinkVerifier = baseUpkeepStorage.chainlinkVerifier;
        forwarder = baseUpkeepStorage.forwarder;
        perpsEngine = address(baseUpkeepStorage.perpsEngine);
        marketId = self.marketId;
        settlementId = self.settlementId;
    }

    function getOcoOrders(uint256 lowerBound, uint256 upperBound) external view returns (OcoOrder.Data[] memory) {
        uint256 amountOfOrders =
            self.accountsWithActiveOrders.length() > upperBound ? upperBound : self.accountsWithActiveOrders.length();

        if (amountOfOrders == 0) {
            return (upkeepNeeded, performData);
        }

        OcoOrder.Data[] memory ocoOrders = new OcoOrder.Data[](amountOfOrders);

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

    function _getOcoOrderSettlementStrategyStorage() internal pure returns (OcoOrderUpkeepStorage storage self) {
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
