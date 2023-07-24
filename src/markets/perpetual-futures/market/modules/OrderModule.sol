// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IOrderModule } from "../interfaces/IOrderModule.sol";
import { Order } from "../storage/Order.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { PerpsMarketConfig } from "../storage/PerpsMarketConfig.sol";
import { Position } from "../storage/Position.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO } from "@prb-math/SD59x18.sol";

contract OrderModule is IOrderModule {
    using SafeERC20 for IERC20;
    using PerpsMarketConfig for PerpsMarketConfig.Data;
    using Position for Position.Data;

    function fillPrice(UD60x18 size) external view returns (UD60x18) {
        PerpsMarketConfig.Data storage perpsMarketConfig = PerpsMarketConfig.load();
        return perpsMarketConfig.getIndexPrice();
    }

    function getOrderFees() external view returns (OrderFees.Data memory) {
        PerpsMarketConfig.Data storage perpsMarketConfig = PerpsMarketConfig.load();
        return perpsMarketConfig.orderFees;
    }

    function getOrders(address account) external view returns (Order.Data[] memory) { }

    function createOrder(Order.Data calldata order) external { }

    function settleOrder(bytes32 orderId) external { }

    function settleOrder(Order.Data calldata order) external {
        PerpsMarketConfig.Data storage perpsMarketConfig = PerpsMarketConfig.load();
        UD60x18 currentPrice = perpsMarketConfig.getIndexPrice();
        _requireOrderIsValid(order, currentPrice);

        // TODO: apply fees
        OrderFees.Data memory orderFees = perpsMarketConfig.orderFees;

        Position.Data storage position = perpsMarketConfig.positions[msg.sender];
        Position.Data memory newPosition = Position.Data({
            size: sd59x18(position.size).add(sd59x18(order.sizeDelta)).intoInt256(),
            lastInteractionPrice: currentPrice.intoUint256(),
            lastInteractionFunding: 0
        });
        position.updatePosition(newPosition);

        emit LogSettleOrder(msg.sender, order, newPosition);
    }

    function cancelOrder(bytes32 orderId) external { }

    function _requireOrderIsValid(Order.Data memory order, UD60x18 currentPrice) internal {
        // if (sd59x18(order.sizeDelta).gt(SD_ZERO)) {
        //     if (ud60x18(order.desiredPrice).gt(currentPrice)) {
        //         revert Zaros_OrderModule_PriceImpact(order.desiredPrice, currentPrice.intoUint256());
        //     }
        // } else {
        //     if (ud60x18(order.desiredPrice).lt(currentPrice)) {
        //         revert Zaros_OrderModule_PriceImpact(order.desiredPrice, currentPrice.intoUint256());
        //     }
        // }
        if (order.filled) {
            revert();
        }
    }
}
