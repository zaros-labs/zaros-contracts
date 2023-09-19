// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

// Zaros dependencies
import { IPerpsExchange } from "../interfaces/IPerpsExchange.sol";
import { IOrderModule } from "../interfaces/IOrderModule.sol";
import { Order } from "../storage/Order.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { PerpsMarket } from "../storage/PerpsMarket.sol";
import { Position } from "../storage/Position.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

abstract contract OrderModule is IOrderModule {
    using SafeERC20 for IERC20;
    using Order for Order.Data;
    using PerpsAccount for PerpsAccount.Data;
    using PerpsMarket for PerpsMarket.Data;
    using Position for Position.Data;

    /// @inheritdoc IOrderModule
    function getConfiguredOrderFees(uint128 marketId) external view returns (OrderFees.Data memory) {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);
        return perpsMarket.orderFees;
    }

    /// @inheritdoc IOrderModule
    function estimateOrderFee(uint128 marketId, int128 sizeDelta) external view returns (UD60x18, UD60x18) { }

    /// @inheritdoc IOrderModule
    function getRequiredMarginForOrder(uint128 marketId, int128 sizeDelta) external view returns (UD60x18, UD60x18) { }

    /// @inheritdoc IOrderModule
    function getOrders(uint256 accountId, uint128 marketId) external view returns (Order.Data[] memory) {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);
        return perpsMarket.orders[accountId];
    }

    /// @inheritdoc IOrderModule
    function createOrder(uint256 accountId, uint128 marketId, Order.Payload calldata orderPayload) external {
        PerpsAccount.Data storage perpsAccount = PerpsAccount.loadAccountAndValidatePermission(accountId);
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);

        if (perpsAccount.canBeLiquidated()) {
            revert Zaros_OrderModule_AccountLiquidatable(msg.sender, accountId);
        }
    }

    // function settleOrder(bytes32 orderId) external { }

    /// @inheritdoc IOrderModule
    function cancelOrder(uint256 accountId, uint128 marketId, uint8 orderId) external {
        PerpsAccount.Data storage perpsAccount = PerpsAccount.loadAccountAndValidatePermission(accountId);
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);
        Order.Data storage order = perpsMarket.orders[accountId][orderId];

        perpsMarket.updateAccountActiveOrders(accountId, orderId, false);
        order.reset();

        emit LogCancelOrder(msg.sender, accountId, marketId, orderId);
    }

    // function settleOrderFromVault(
    //     uint256 accountId,
    //     Order.Data calldata order
    // )
    //     external
    //     returns (uint256 previousPositionAmount)
    // {
    //     PerpsMarket.Data storage perpsMarket = PerpsMarket.load();
    //     if (msg.sender != perpsMarket.perpsExchange) {
    //         revert();
    //     }

    //     return _settleOrder(accountId, order);
    // }

    // function _settleOrder(
    //     uint256 accountId,
    //     Order.Data memory order
    // )
    //     internal
    //     returns (uint256 previousPositionAmount)
    // {
    //     PerpsMarket.Data storage perpsMarket = PerpsMarket.load();
    //     UD60x18 currentPrice = perpsMarket.getIndexPrice();
    //     _requireOrderIsValid(order, currentPrice);

    //     OrderFees.Data memory orderFees = perpsMarket.orderFees;
    //     Position.Data storage position = perpsMarket.positions[accountId];
    //     previousPositionAmount = position.margin.amount;
    //     IPerpsExchange perpsExchange = IPerpsExchange(perpsMarket.perpsExchange);
    //     UD60x18 sizeAbs = sd59x18(order.sizeDelta).lt(SD_ZERO)
    //         ? unary(sd59x18(order.sizeDelta)).intoUD60x18()
    //         : sd59x18(order.sizeDelta).intoUD60x18();
    //     /// TODO: fix this
    //     UD60x18 fee = sizeAbs.mul(ud60x18(orderFees.takerFee));

    //     if (ud60x18(order.marginAmount).gt(ud60x18(position.margin.amount))) {
    //         // perpsExchange.addIsolatedMarginToPosition(
    //         //     accountId, order.collateralType, ud60x18(order.marginAmount).sub(ud60x18(position.margin.amount)),
    //         // fee
    //         // );
    //     } else if (ud60x18(order.marginAmount).lt(ud60x18(position.margin.amount))) {
    //         IERC20(order.collateralType).safeTransfer(
    //             address(perpsExchange),
    // ud60x18(position.margin.amount).sub(ud60x18(order.marginAmount)).intoUint256()
    //         );
    //         // perpsExchange.removeIsolatedMarginFromPosition(
    //         //     accountId, order.collateralType, ud60x18(position.margin.amount).sub(ud60x18(order.marginAmount))
    //         // );
    //     }

    //     Position.Data memory newPosition = Position.Data({
    //         margin: Position.Margin({ collateralType: order.collateralType, amount: order.marginAmount }),
    //         size: sd59x18(position.size).add(sd59x18(order.sizeDelta)).intoInt256(),
    //         lastInteractionPrice: currentPrice.intoUint256(),
    //         lastInteractionFunding: 0
    //     });
    //     position.updatePosition(newPosition);

    //     emit LogSettleOrder(msg.sender, accountId, order, newPosition);
    // }

    // function _requireOrderIsValid(Order.Data memory order, UD60x18 currentPrice) internal {
    //     // if (sd59x18(order.sizeDelta).gt(SD_ZERO)) {
    //     //     if (ud60x18(order.desiredPrice).gt(currentPrice)) {
    //     //         revert Zaros_OrderModule_PriceImpact(order.desiredPrice, currentPrice.intoUint256());
    //     //     }
    //     // } else {
    //     //     if (ud60x18(order.desiredPrice).lt(currentPrice)) {
    //     //         revert Zaros_OrderModule_PriceImpact(order.desiredPrice, currentPrice.intoUint256());
    //     //     }
    //     // }
    //     if (order.filled) {
    //         revert();
    //     }
    // }
}
