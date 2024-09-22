// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract WEthCoreVault {
    uint128 internal constant WETH_CORE_VAULT_ID = 14;
    string internal constant WETH_CORE_VAULT_NAME = "WEth Core ZLP Vault";
    string internal constant WETH_CORE_VAULT_SYMBOL = "WEth-ZLP Core";
    uint128 internal constant WETH_CORE_VAULT_DEPOSIT_CAP = 2e18;
    uint128 internal constant WETH_CORE_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant WETH_CORE_VAULT_IS_ENABLED = true;
    uint256 internal constant WETH_CORE_VAULT_CREDIT_RATIO = 2e18;
}