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
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

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

    function getOrders(uint256 accountId) external view returns (Order.Data[] memory) { }

    function createOrder(Order.Data calldata order) external { }

    function settleOrder(bytes32 orderId) external { }

    function cancelOrder(bytes32 orderId) external { }

    function settleOrderFromVault(
        uint256 accountId,
        Order.Data calldata order
    )
        external
        returns (uint256 previousPositionAmount)
    {
        PerpsMarketConfig.Data storage perpsMarketConfig = PerpsMarketConfig.load();
        if (msg.sender != perpsMarketConfig.perpsVault) {
            revert();
        }

        return _settleOrder(accountId, order);
    }

    function _settleOrder(
        uint256 accountId,
        Order.Data memory order
    )
        internal
        returns (uint256 previousPositionAmount)
    {
        PerpsMarketConfig.Data storage perpsMarketConfig = PerpsMarketConfig.load();
        UD60x18 currentPrice = perpsMarketConfig.getIndexPrice();
        _requireOrderIsValid(order, currentPrice);

        OrderFees.Data memory orderFees = perpsMarketConfig.orderFees;
        Position.Data storage position = perpsMarketConfig.positions[accountId];
        previousPositionAmount = position.margin.amount;
        IPerpsVault perpsVault = IPerpsVault(perpsMarketConfig.perpsVault);
        UD60x18 sizeAbs = sd59x18(order.sizeDelta).lt(SD_ZERO)
            ? unary(sd59x18(order.sizeDelta)).intoUD60x18()
            : sd59x18(order.sizeDelta).intoUD60x18();
        /// TODO: fix this
        UD60x18 fee = sizeAbs.mul(ud60x18(orderFees.takerFee));

        if (ud60x18(order.marginAmount).gt(ud60x18(position.margin.amount))) {
            perpsVault.addIsolatedMarginToPosition(
                accountId, order.collateralType, ud60x18(order.marginAmount).sub(ud60x18(position.margin.amount)), fee
            );
        } else if (ud60x18(order.marginAmount).lt(ud60x18(position.margin.amount))) {
            IERC20(order.collateralType).safeTransfer(
                address(perpsVault), ud60x18(position.margin.amount).sub(ud60x18(order.marginAmount)).intoUint256()
            );
            perpsVault.removeIsolatedMarginFromPosition(
                accountId, order.collateralType, ud60x18(position.margin.amount).sub(ud60x18(order.marginAmount))
            );
        }

        Position.Data memory newPosition = Position.Data({
            margin: Position.Margin({ collateralType: order.collateralType, amount: order.marginAmount }),
            size: sd59x18(position.size).add(sd59x18(order.sizeDelta)).intoInt256(),
            lastInteractionPrice: currentPrice.intoUint256(),
            lastInteractionFunding: 0
        });
        position.updatePosition(newPosition);

        emit LogSettleOrder(msg.sender, accountId, order, newPosition);
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
