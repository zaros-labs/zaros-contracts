// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Order } from "../storage/Order.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { Position } from "../storage/Position.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

interface IOrderModule {
    error Zaros_OrderModule_AccountLiquidatable(address sender, uint256 accountId);

    // event LogSettleOrder(
    //     address indexed sender, uint256 indexed accountId, Order.Data order, Position.Data newPosition
    // );

    event LogCancelOrder(address indexed sender, uint256 indexed accountId, uint128 indexed marketId, uint8 orderId);

    function getConfiguredOrderFees(uint128 marketId) external view returns (OrderFees.Data memory orderFees);

    function getOrders(uint256 accountId, uint128 marketId) external view returns (Order.Data[] memory orders);

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

    function createOrder(uint256 accountId, uint128 marketId, Order.Payload calldata orderPayload) external;

    // function settleOrder(bytes32 orderId) external;

    function cancelOrder(uint256 accountId, uint128 marketId, uint8 orderId) external;
}
