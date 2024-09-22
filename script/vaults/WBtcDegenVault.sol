// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract WBtcDegenVault {
    uint128 internal constant WBTC_DEGEN_VAULT_ID = 12;
    string internal constant WBTC_DEGEN_VAULT_NAME = "WBtc Degen ZLP Vault";
    string internal constant WBTC_DEGEN_VAULT_SYMBOL = "WBtc-ZLP Degen";
    uint128 internal constant WBTC_DEGEN_VAULT_DEPOSIT_CAP = 2e18;
    uint128 internal constant WBTC_DEGEN_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant WBTC_DEGEN_VAULT_IS_ENABLED = true;
    uint256 internal constant WBTC_DEGEN_VAULT_CREDIT_RATIO = 2e18;
}