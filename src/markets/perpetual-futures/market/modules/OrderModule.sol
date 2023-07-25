// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsVault } from "../../vault/interfaces/IPerpsVault.sol";
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
        _settleOrder(msg.sender, order);
    }

    function cancelOrder(bytes32 orderId) external { }

    function settleOrderFromVault(address account, Order.Data calldata order) external {
        PerpsMarketConfig.Data storage perpsMarketConfig = PerpsMarketConfig.load();
        if (msg.sender != perpsMarketConfig.perpsVault) {
            revert();
        }

        _settleOrder(account, order);
    }

    function _settleOrder(address account, Order.Data memory order) internal {
        PerpsMarketConfig.Data storage perpsMarketConfig = PerpsMarketConfig.load();
        UD60x18 currentPrice = perpsMarketConfig.getIndexPrice();
        _requireOrderIsValid(order, currentPrice);

        // TODO: apply fees
        OrderFees.Data memory orderFees = perpsMarketConfig.orderFees;

        IPerpsVault perpsVault = IPerpsVault(perpsMarketConfig.perpsVault);
        perpsVault.addIsolatedMarginToPosition(account, order.collateralType, ud60x18(order.marginAmount));

        Position.Data storage position = perpsMarketConfig.positions[account];
        Position.Data memory newPosition = Position.Data({
            margin: Position.Margin({ collateralType: order.collateralType, amount: order.marginAmount }),
            size: sd59x18(position.size).add(sd59x18(order.sizeDelta)).intoInt256(),
            lastInteractionPrice: currentPrice.intoUint256(),
            lastInteractionFunding: 0
        });
        position.updatePosition(newPosition);

        emit LogSettleOrder(account, order, newPosition);
    }

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
