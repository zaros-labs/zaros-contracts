// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract WstEthCoreVault {
    uint128 internal constant WSTETH_CORE_VAULT_ID = 5;
    string internal constant WSTETH_CORE_VAULT_NAME = "WstEth Core ZLP Vault";
    string internal constant WSTETH_CORE_VAULT_SYMBOL = "WstEth-ZLP Core";
    uint128 internal constant WSTETH_CORE_VAULT_DEPOSIT_CAP = 2e18;
    uint128 internal constant WSTETH_CORE_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant WSTETH_CORE_VAULT_IS_ENABLED = true;
    uint256 internal constant WSTETH_CORE_VAULT_CREDIT_RATIO = 2e18;
    uint256 internal constant WSTETH_CORE_VAULT_DEPOSIT_FEE = 0.01e18;
    uint256 internal constant WSTETH_CORE_VAULT_REDEEM_FEE = 0.05e18;
    address internal constant WSTETH_CORE_VAULT_ENGINE = address(0); // the address will be updated in the mainnet
}
