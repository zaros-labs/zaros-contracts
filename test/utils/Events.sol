// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.25;

// Zaros dependencies
import { MarketOrder } from "@zaros/perpetuals/leaves/MarketOrder.sol";
import { Position } from "@zaros/perpetuals/leaves/Position.sol";

// TODO: use native branches events
/// @notice Abstract contract containing all the events emitted by all branches.
abstract contract Events {
    /*//////////////////////////////////////////////////////////////////////////
                                   PERPS ACCOUNT MODULE
    //////////////////////////////////////////////////////////////////////////*/

    event LogCreatePerpsAccount(uint128 accountId, address sender);
    event LogDepositMargin(
        address indexed sender, uint128 indexed accountId, address indexed collateralType, uint256 amount
    );
    event LogWithdrawMargin(
        address indexed sender, uint128 indexed accountId, address indexed collateralType, uint256 amount
    );

    /*//////////////////////////////////////////////////////////////////////////
                                   PERPS CONFIGURATION MODULE
    //////////////////////////////////////////////////////////////////////////*/

    event LogSetSupportedMarket(address indexed perpMarket, bool enabled);
    event LogSetSupportedCollateral(address indexed sender, address indexed collateralType, bool enabled);

    /*//////////////////////////////////////////////////////////////////////////
                                   ORDER MODULE
    //////////////////////////////////////////////////////////////////////////*/
    event LogCreateMarketOrder(
        address indexed sender, uint128 indexed accountId, uint128 indexed marketId, MarketOrder.Data marketOrder
    );
    // event LogCancelMarketOrder(address indexed sender, uint128 indexed accountId, uint128 indexed marketId,
    // uint8
    // orderId);

    /*//////////////////////////////////////////////////////////////////////////
                                   SETTLEMENT MODULE
    //////////////////////////////////////////////////////////////////////////*/
    event LogSettleOrder(
        address indexed sender, uint128 indexed accountId, uint128 indexed marketId, Position.Data newPosition
    );
}
