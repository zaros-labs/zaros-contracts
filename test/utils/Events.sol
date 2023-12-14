// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { MarketOrder } from "@zaros/markets/perps/storage/MarketOrder.sol";
import { Position } from "@zaros/markets/perps/storage/Position.sol";

/// @notice Abstract contract containing all the events emitted by all modules.
abstract contract Events {
    /*//////////////////////////////////////////////////////////////////////////
                                   PERPS ACCOUNT MODULE
    //////////////////////////////////////////////////////////////////////////*/

    event LogCreatePerpsAccount(uint128 accountId, address sender);
    event LogDepositMargin(
        address indexed sender, uint256 indexed accountId, address indexed collateralType, uint256 amount
    );
    event LogWithdrawMargin(
        address indexed sender, uint256 indexed accountId, address indexed collateralType, uint256 amount
    );

    /*//////////////////////////////////////////////////////////////////////////
                                   PERPS CONFIGURATION MODULE
    //////////////////////////////////////////////////////////////////////////*/

    event LogSetSupportedMarket(address indexed perpsMarket, bool enabled);
    event LogSetSupportedCollateral(address indexed sender, address indexed collateralType, bool enabled);

    /*//////////////////////////////////////////////////////////////////////////
                                   ORDER MODULE
    //////////////////////////////////////////////////////////////////////////*/
    event LogCreateMarketOrder(
        address indexed sender, uint256 indexed accountId, uint128 indexed marketId, MarketOrder.Data marketOrder
    );
    // event LogCancelMarketOrder(address indexed sender, uint256 indexed accountId, uint128 indexed marketId, uint8
    // orderId);

    /*//////////////////////////////////////////////////////////////////////////
                                   SETTLEMENT MODULE
    //////////////////////////////////////////////////////////////////////////*/
    event LogSettleOrder(
        address indexed sender, uint256 indexed accountId, uint128 indexed marketId, Position.Data newPosition
    );
}
