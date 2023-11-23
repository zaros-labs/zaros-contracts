// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

// Zaros dependencies
import { Order } from "@zaros/markets/perps/storage/Order.sol";
import { Position } from "@zaros/markets/perps/storage/Position.sol";

/// @notice Abstract contract containing all the events emitted by all modules.
abstract contract Events {
    /*//////////////////////////////////////////////////////////////////////////
                                   PERPS ACCOUNT MODULE
    //////////////////////////////////////////////////////////////////////////*/

    event LogCreatePerpsAccount(uint256 accountId, address sender);
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
    event LogCreateOrder(address indexed sender, uint256 indexed accountId, uint128 indexed marketId, Order.Data order);
    event LogCancelOrder(address indexed sender, uint256 indexed accountId, uint128 indexed marketId, uint8 orderId);

    /*//////////////////////////////////////////////////////////////////////////
                                   SETTLEMENT MODULE
    //////////////////////////////////////////////////////////////////////////*/
    event LogSettleOrder(
        address indexed sender,
        uint256 indexed accountId,
        uint128 indexed marketId,
        uint8 orderId,
        Position.Data newPosition
    );
}
