// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract WeEthDegenVault {
    uint128 internal constant WEETH_DEGEN_VAULT_ID = 3;
    string internal constant WEETH_DEGEN_VAULT_NAME = "weETH Degen ZLP Vault";
    string internal constant WEETH_DEGEN_VAULT_SYMBOL = "weETH-ZLP Degen";
    uint128 internal constant WEETH_DEGEN_VAULT_DEPOSIT_CAP = 2e18;
    uint128 internal constant WEETH_DEGEN_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant WEETH_DEGEN_VAULT_IS_ENABLED = true;
    uint256 internal constant WEETH_DEGEN_VAULT_CREDIT_RATIO = 2e18;
}