// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

abstract contract Storage {
    /// @dev GlobalConfiguration namespace storage slot.
    bytes32 internal constant GLOBAL_CONFIGURATION_SLOT = keccak256(abi.encode("fi.zaros.markets.GlobalConfiguration"));
    /// @dev Constant base domain used to access a given PerpsAccount's storage slot.
    string internal constant PERPS_ACCOUNT_DOMAIN = "fi.zaros.markets.PerpsAccount";
    /// @dev Constant base domain used to access a given PerpMarket's storage slot.
    string internal constant PERPS_MARKET_DOMAIN = "fi.zaros.markets.PerpMarket";
}
