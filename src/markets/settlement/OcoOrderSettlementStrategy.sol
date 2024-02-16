// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { IPerpsEngine } from "@zaros/markets/perps/interfaces/IPerpsEngine.sol";
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { DataStreamsSettlementStrategy } from "./DataStreamsSettlementStrategy.sol";
import { OcoOrder } from "./storage/OcoOrder.sol";

// Open Zeppelin dependencies
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

contract OcoOrderSettlementStrategy is DataStreamsSettlementStrategy {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeCast for uint256;

    enum Actions {
        UPDATE_OCO_ORDER
    }

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

    constructor() {
        _disableInitializers();
    }

    /// @notice {OcoOrderSettlementStrategy} UUPS initializer.
    function initialize(IPerpsEngine perpsEngine, uint128 marketId, uint128 settlementId) external initializer {
        __DataStreamsSettlementStrategy_init(perpsEngine, marketId, settlementId);
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

    function callback(ISettlementModule.SettlementPayload[] calldata payloads) external override onlyPerpsEngine {
        OcoOrderSettlementStrategyStorage storage self = _getOcoOrderSettlementStrategyStorage();

        for (uint256 i = 0; i < payloads.length; i++) {
            uint128 accountId = payloads[i].accountId;
            bool isAccountWithOcoOrder = self.accountsWithActiveOrders.contains(accountId);

            if (isAccountWithOcoOrder) {
                _updateOcoOrder(
                    accountId, OcoOrder.TakeProfit({ price: 0 }), OcoOrder.StopLoss({ price: 0 }), false, 0
                );
            }
        }
    }

    function dispatch(uint128 accountId, bytes calldata extraData) external override onlyPerpsEngine {
        (Actions action) = abi.decode(extraData[0:8], (Actions));

        if (action == Actions.UPDATE_OCO_ORDER) {
            (OcoOrder.TakeProfit memory takeProfit, OcoOrder.StopLoss memory stopLoss, bool isLong) =
                abi.decode(extraData[8:], (OcoOrder.TakeProfit, OcoOrder.StopLoss, bool));
            DataStreamsSettlementStrategyStorage storage dataStreamsCustomSettlementStrategyStorage =
                _getDataStreamsSettlementStrategyStorage();
            IPerpsEngine perpsEngine = dataStreamsCustomSettlementStrategyStorage.perpsEngine;
            uint128 marketId = dataStreamsCustomSettlementStrategyStorage.marketId;

            UD60x18 markPriceX18 = perpsEngine.getMarkPrice(marketId, 0);

            _updateOcoOrder(accountId, takeProfit, stopLoss, isLong, markPriceX18.intoUint256());
        } else {
            revert Errors.InvalidSettlementStrategyAction();
        }
    }

    struct ExecuteTradeContext {
        IPerpsEngine perpsEngine;
        uint128 marketId;
        uint128 settlementId;
        ISettlementModule.SettlementPayload[] payloads;
    }

    function executeTrade(
        bytes calldata signedReport,
        bytes calldata extraData
    )
        external
        override
        onlyRegisteredKeeper
    {
        ExecuteTradeContext memory ctx;

        DataStreamsSettlementStrategyStorage storage dataStreamsCustomSettlementStrategyStorage =
            _getDataStreamsSettlementStrategyStorage();
        (ctx.perpsEngine, ctx.marketId, ctx.settlementId) = (
            dataStreamsCustomSettlementStrategyStorage.perpsEngine,
            dataStreamsCustomSettlementStrategyStorage.marketId,
            dataStreamsCustomSettlementStrategyStorage.settlementId
        );

        ctx.payloads = abi.decode(extraData, (ISettlementModule.SettlementPayload[]));
        // TODO: Update the fee receiver to an address stored / managed by the keeper.
        ctx.perpsEngine.settleCustomOrders(
            ctx.marketId, ctx.settlementId, msg.sender, ctx.payloads, signedReport, address(0)
        );
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
        OcoOrder.StopLoss memory stopLoss,
        bool isLong,
        uint256 markPriceX18
    )
        internal
    {
        OcoOrderSettlementStrategyStorage storage self = _getOcoOrderSettlementStrategyStorage();

        if (takeProfit.price != 0 && isLong && takeProfit.price < stopLoss.price) {
            revert Errors.InvalidOcoOrder();
        } else if (takeProfit.price != 0 && !isLong && takeProfit.price > stopLoss.price) {
            revert Errors.InvalidOcoOrder();
        }

        bool isAccountWithNewOcoOrder =
            takeProfit.price != 0 || stopLoss.price != 0 && !self.accountsWithActiveOrders.contains(accountId);
        bool isAccountCancellingOcoOrder =
            takeProfit.price == 0 && stopLoss.price == 0 && self.accountsWithActiveOrders.contains(accountId);

        bool isValidOcoOrder = !isAccountCancellingOcoOrder && isLong
            ? (takeProfit.price > markPriceX18 && stopLoss.price < markPriceX18)
            : (takeProfit.price < markPriceX18 && stopLoss.price > markPriceX18);

        if (!isValidOcoOrder) {
            revert Errors.InvalidOcoOrder();
        }

        if (isAccountWithNewOcoOrder) {
            self.accountsWithActiveOrders.add(accountId);
        } else if (isAccountCancellingOcoOrder) {
            self.accountsWithActiveOrders.remove(accountId);
        }

        self.ocoOrderOfAccount[accountId] =
            OcoOrder.Data({ accountId: accountId, isLong: isLong, takeProfit: takeProfit, stopLoss: stopLoss });

        emit LogCreateOcoOrder(msg.sender, accountId, takeProfit, stopLoss);
    }
}
