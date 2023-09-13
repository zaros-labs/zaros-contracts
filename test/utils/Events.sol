// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

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
                                   SYSTEM PERPS MARKETS CONFIGURATION MODULE
    //////////////////////////////////////////////////////////////////////////*/

    event LogSetSupportedMarket(address indexed perpsMarket, bool enabled);
    event LogSetSupportedCollateral(address indexed sender, address indexed collateralType, bool enabled);
}
