// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { Order } from "../storage/Order.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { Position } from "../storage/Position.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

interface IOrderModule {
    error Zaros_OrderModule_PriceImpact(uint256 desiredPrice, uint256 currentPrice);

    event LogSettleOrder(address indexed sender, Order.Data order, Position.Data newPosition);

    function fillPrice(UD60x18 size) external view returns (UD60x18);

    function getOrderFees() external view returns (OrderFees.Data memory);

    function getOrders(address account) external view returns (Order.Data[] memory);

    function createOrder(Order.Data calldata order) external;

    function settleOrder(bytes32 orderId) external;

    /// @dev TODO: Improve this
    function settleOrder(Order.Data calldata order) external;

    function cancelOrder(bytes32 orderId) external;

    function settleOrderFromVault(
        address account,
        Order.Data calldata order
    )
        external
        returns (uint256 previousPositionAmount);
}
