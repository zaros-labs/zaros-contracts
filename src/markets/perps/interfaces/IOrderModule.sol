// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { MarketOrder } from "../storage/MarketOrder.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { Position } from "../storage/Position.sol";
import { SettlementConfiguration } from "../storage/SettlementConfiguration.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

interface IOrderModule {
    event LogCreateMarketOrder(
        address indexed sender, uint256 indexed accountId, uint128 indexed marketId, MarketOrder.Data marketOrder
    );

    function getConfiguredOrderFees(uint128 marketId) external view returns (OrderFees.Data memory orderFees);

    function getActiveMarketOrder(
        uint128 accountId,
        uint128 marketId
    )
        external
        view
        returns (MarketOrder.Data memory marketOrder);

    function estimateOrderFee(
        uint128 marketId,
        int128 sizeDelta
    )
        external
        view
        returns (UD60x18 fee, UD60x18 fillPrice);

    function getRequiredMarginForOrder(
        uint128 marketId,
        int128 sizeDelta
    )
        external
        view
        returns (UD60x18 minimumInitialMargin, UD60x18 maintenanceMargin);

    function createMarketOrder(
        uint128 accountId,
        uint128 marketId,
        int128 sizeDelta,
        uint128 acceptablePrice
    )
        external;

    function cancelMarketOrder(uint128 accountId, uint128 marketId, uint8 orderId) external;

    function dispatchCustomSettlementRequest(
        uint128 accountId,
        uint128 marketId,
        uint128 settlementId,
        bool isAccountStrategy,
        bytes calldata extraData
    )
        external
        returns (bytes memory);
}
