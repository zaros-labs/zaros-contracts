// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Errors } from "@zaros/utils/Errors.sol";
import { IPerpsEngine } from "../interfaces/IPerpsEngine.sol";
import { IOrderModule } from "../interfaces/IOrderModule.sol";
import { Order } from "../storage/Order.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { PerpsAccount } from "../storage/PerpsAccount.sol";
import { PerpsMarket } from "../storage/PerpsMarket.sol";
import { Position } from "../storage/Position.sol";
import { SettlementStrategy } from "../storage/SettlementStrategy.sol";

// Open Zeppelin dependencies
import { IERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";
import { SafeCast } from "@openzeppelin/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18, sd59x18, ZERO as SD_ZERO, unary } from "@prb-math/SD59x18.sol";

abstract contract OrderModule is IOrderModule {
    using SafeCast for uint256;
    using SafeERC20 for IERC20;
    using Order for Order.Data;
    using PerpsAccount for PerpsAccount.Data;
    using PerpsMarket for PerpsMarket.Data;
    using Position for Position.Data;

    /// @inheritdoc IOrderModule
    function getConfiguredOrderFees(uint128 marketId) external view override returns (OrderFees.Data memory) {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);
        return perpsMarket.orderFees;
    }

    /// @inheritdoc IOrderModule
    function estimateOrderFee(uint128 marketId, int128 sizeDelta) external view override returns (UD60x18, UD60x18) { }

    /// @inheritdoc IOrderModule
    function getRequiredMarginForOrder(
        uint128 marketId,
        int128 sizeDelta
    )
        external
        view
        override
        returns (UD60x18, UD60x18)
    { }

    /// @inheritdoc IOrderModule
    function getOrders(uint256 accountId, uint128 marketId) external view override returns (Order.Data[] memory) {
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);
        return perpsMarket.orders[accountId];
    }

    /// @inheritdoc IOrderModule
    /// @dev TODO: remove accountId and marketId since they're already present in the payload
    function createOrder(Order.Payload calldata payload) external override {
        uint256 accountId = payload.accountId;
        uint128 marketId = payload.marketId;
        PerpsAccount.Data storage perpsAccount = PerpsAccount.loadAccountAndValidatePermission(accountId);
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);
        SettlementStrategy.Data storage settlementStrategy = perpsMarket.settlementStrategy;

        if (perpsAccount.canBeLiquidated()) {
            revert Errors.AccountLiquidatable(msg.sender, accountId);
        }

        // TODO: validate order
        uint8 orderId = (perpsMarket.orders[accountId].length).toUint8();
        Order.Data memory order =
            Order.Data({ id: orderId, payload: payload, settlementTimestamp: block.timestamp.toUint248() });
        perpsMarket.orders[accountId].push(order);
        perpsAccount.updateActiveOrders(marketId, orderId, true);

        emit LogCreateOrder(msg.sender, accountId, marketId, order.id, order.settlementTimestamp, settlementStrategy);
    }

    /// @inheritdoc IOrderModule
    function cancelOrder(uint256 accountId, uint128 marketId, uint8 orderId) external override {
        PerpsAccount.Data storage perpsAccount = PerpsAccount.loadAccountAndValidatePermission(accountId);
        PerpsMarket.Data storage perpsMarket = PerpsMarket.load(marketId);
        Order.Data storage order = perpsMarket.orders[accountId][orderId];

        perpsAccount.updateActiveOrders(marketId, orderId, false);
        order.reset();

        emit LogCancelOrder(msg.sender, accountId, marketId, orderId);
    }
}
