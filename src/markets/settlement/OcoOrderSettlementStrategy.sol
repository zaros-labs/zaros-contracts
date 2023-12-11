// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

// Zaros dependencies
import { ISettlementModule } from "@zaros/markets/perps/interfaces/ISettlementModule.sol";
import { SettlementConfiguration } from "@zaros/markets/perps/storage/SettlementConfiguration.sol";
import { ISettlementStrategy } from "./interfaces/ISettlementStrategy.sol";
import { DataStreamsSettlementStrategy } from "./DataStreamsSettlementStrategy.sol";

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
}
