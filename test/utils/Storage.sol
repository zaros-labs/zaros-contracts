// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract Storage {
    /// @dev GlobalConfiguration namespace storage slot.
    bytes32 internal constant GLOBAL_CONFIGURATION_SLOT =
        keccak256(abi.encode("fi.zaros.markets.GlobalConfiguration"));
    /// @dev Constant base domain used to access a given TradingAccount's storage slot.
    string internal constant TRADING_ACCOUNT_DOMAIN = "fi.zaros.markets.TradingAccount";
    /// @dev Constant base domain used to access a given PerpMarket's storage slot.
    string internal constant PERPS_MARKET_DOMAIN = "fi.zaros.markets.PerpMarket";
    /// @notice Constant base domain used to access a given Position's storage slot.
    string internal constant POSITION_DOMAIN = "fi.zaros.markets.perps.storage.Position";
}
