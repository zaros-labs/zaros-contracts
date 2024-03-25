// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { MarketOrder } from "../storage/MarketOrder.sol";
import { OrderFees } from "../storage/OrderFees.sol";
import { Position } from "../storage/Position.sol";
import { SettlementConfiguration } from "../storage/SettlementConfiguration.sol";

// PRB Math dependencies
import { UD60x18 } from "@prb-math/UD60x18.sol";
import { SD59x18 } from "@prb-math/SD59x18.sol";

interface IOrderModule {
    event LogCreateMarketOrder(
        address indexed sender, uint128 indexed accountId, uint128 indexed marketId, MarketOrder.Data marketOrder
    );
    event LogCancelMarketOrder(address indexed sender, uint128 indexed accountId);

    function getConfiguredOrderFees(uint128 marketId) external view returns (OrderFees.Data memory orderFees);

    function getActiveMarketOrder(uint128 accountId) external view returns (MarketOrder.Data memory marketOrder);

    /// @notice Simulates the settlement costs and validity of a given order.
    /// @dev Reverts if there's not enough margin to cover the trade.
    /// @param accountId The trading account id.
    /// @param marketId The perp market id.
    /// @param settlementId The perp market settlement strategy id.
    /// @param sizeDelta The size delta of the order.
    /// @return marginBalanceUsdX18 The given account's current margin balance.
    /// @return requiredInitialMarginUsdX18 The required initial margin to settle the given trade.
    /// @return requiredMaintenanceMarginUsdX18 The required maintenance margin to settle the given trade.
    /// @return orderFeeUsdX18 The order fee in USD.
    /// @return settlementFeeUsdX18 The settlement fee in USD.
    /// @return fillPriceX18 The fill price quote.
    function simulateTrade(
        uint128 accountId,
        uint128 marketId,
        uint128 settlementId,
        int128 sizeDelta
    )
        external
        view
        returns (
            SD59x18 marginBalanceUsdX18,
            UD60x18 requiredInitialMarginUsdX18,
            UD60x18 requiredMaintenanceMarginUsdX18,
            SD59x18 orderFeeUsdX18,
            UD60x18 settlementFeeUsdX18,
            UD60x18 fillPriceX18
        );

    function getMarginRequirementsForTrade(
        uint128 marketId,
        int128 sizeDelta
    )
        external
        view
        returns (UD60x18 initialMarginUsdX18, UD60x18 maintenanceMarginUsdX18);

    struct CreateMarketOrderParams {
        uint128 accountId;
        uint128 marketId;
        int128 sizeDelta;
        uint128 acceptablePrice;
    }

    struct CreateMarketOrderContext {
        SD59x18 marginBalanceUsdX18;
        UD60x18 requiredInitialMarginUsdX18;
        UD60x18 requiredMaintenanceMarginUsdX18;
        SD59x18 orderFeeUsdX18;
        UD60x18 settlementFeeUsdX18;
    }

    function createMarketOrder(CreateMarketOrderParams calldata params) external;

    /// @notice Cancels an active market order.
    /// @dev Reverts if there is no active market order for the given account and market.
    /// @param accountId The trading account id.
    function cancelMarketOrder(uint128 accountId) external;

    function createCustomOrder(
        uint128 accountId,
        uint128 marketId,
        uint128 settlementId,
        bool isAccountStrategy,
        bytes calldata extraData
    )
        external
        returns (bytes memory);
}
