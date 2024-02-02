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
    event LogCancelMarketOrder(address indexed sender, uint128 indexed accountId, uint128 indexed marketId);

    function getConfiguredOrderFees(uint128 marketId) external view returns (OrderFees.Data memory orderFees);

    function getActiveMarketOrder(
        uint128 accountId,
        uint128 marketId
    )
        external
        view
        returns (MarketOrder.Data memory marketOrder);

    function simulateSettlement(
        uint128 marketId,
        uint128 settlementId,
        int128 sizeDelta
    )
        external
        view
        returns (SD59x18 orderFeeUsdX18, UD60x18 settlementFeeUsdX18, UD60x18 fillPriceX18);

    function getRequiredMarginForOrder(
        uint128 marketId,
        int128 sizeDelta
    )
        external
        view
        returns (UD60x18 minInitialMarginUsdX18, UD60x18 maintenanceMarginUsdX18);

    function createMarketOrder(
        uint128 accountId,
        uint128 marketId,
        int128 sizeDelta,
        uint128 acceptablePrice
    )
        external;

    /// @notice Cancels an active market order.
    /// @dev Reverts if there is no active market order for the given account and market.
    /// @param accountId The trading account id.
    /// @param marketId The perp market id.
    function cancelMarketOrder(uint128 accountId, uint128 marketId) external;

    function dispatchCustomSettlementRequest(
        uint128 accountId,
        uint128 marketId,
        uint128 settlementId,
        bool isAccountStrategy,
        bytes calldata extraData
    )
        external
        returns (bytes memory);
}
