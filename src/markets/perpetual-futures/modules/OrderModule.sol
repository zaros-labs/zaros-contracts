// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IOrderModule } from "../interfaces/IOrderModule.sol";
import { Order } from "../storage/Order.sol";
import { OrderFees } from "../storage/OrderFees.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";

contract OrderModule is IOrderModule {
    function fillPrice(UD60x18 size) external view returns (UD60x18) { }

    function getOrderFees() external view returns (OrderFees.Data memory) { }

    function getOrders(address account) external view returns (Order.Data[] memory) { }

    function createOrder(Order.Data calldata order) external { }

    function settleOrder(bytes32 orderId) external { }

    function cancelOrder(bytes32 orderId) external { }
}
