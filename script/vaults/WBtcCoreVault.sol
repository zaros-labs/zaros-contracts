// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract WBtcCoreVault {
    uint128 internal constant WBTC_CORE_VAULT_ID = 11;
    string internal constant WBTC_CORE_VAULT_NAME = "WBtc Core ZLP Vault";
    string internal constant WBTC_CORE_VAULT_SYMBOL = "WBtc-ZLP Core";
    uint128 internal constant WBTC_CORE_VAULT_DEPOSIT_CAP = 2e18;
    uint128 internal constant WBTC_CORE_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant WBTC_CORE_VAULT_IS_ENABLED = true;
    uint256 internal constant WBTC_CORE_VAULT_CREDIT_RATIO = 2e18;
}