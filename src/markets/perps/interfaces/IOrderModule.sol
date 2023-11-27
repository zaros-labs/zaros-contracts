// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Order } from "../storage/Order.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { Position } from "../storage/Position.sol";
import { SettlementStrategy } from "../storage/SettlementStrategy.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

interface IOrderModule {
    event LogCreateMarketOrder(
        address indexed sender, uint256 indexed accountId, uint128 indexed marketId, Order.Market marketOrder
    );

    function getConfiguredOrderFees(uint128 marketId) external view returns (OrderFees.Data memory orderFees);

    function getActiveMarketOrder(
        uint128 accountId,
        uint128 marketId
    )
        external
        view
        returns (Order.Market memory marketOrder);

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

    function createMarketOrder(Order.Payload calldata orderPayload) external;

    function cancelOrder(uint128 accountId, uint128 marketId, uint8 orderId) external;
}
