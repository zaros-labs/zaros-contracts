// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

abstract contract Storage {
    /// @dev PerpsConfiguration namespace storage slot.
    bytes32 internal constant PERPS_CONFIGURATION_SLOT =
        keccak256(abi.encode("fi.zaros.markets.PerpsConfiguration"));
    /// @dev Constant base domain used to access a given PerpsAccount's storage slot.
    string internal constant PERPS_ACCOUNT_DOMAIN = "fi.zaros.markets.PerpsAccount";
    /// @dev Constant base domain used to access a given PerpsMarket's storage slot.
    string internal constant PERPS_MARKET_DOMAIN = "fi.zaros.markets.PerpsMarket";
}
