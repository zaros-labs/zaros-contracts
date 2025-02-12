// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract WeEthBluechipVault {
    uint128 internal constant WEETH_BLUECHIP_VAULT_ID = 1;
    string internal constant WEETH_BLUECHIP_VAULT_NAME = "weETH Bluechip ZLP Vault";
    string internal constant WEETH_BLUECHIP_VAULT_SYMBOL = "weETH-ZLP Bluechip";
    uint128 internal constant WEETH_BLUECHIP_VAULT_DEPOSIT_CAP = 2e18;
    uint128 internal constant WEETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant WEETH_BLUECHIP_VAULT_IS_ENABLED = true;
    uint256 internal constant WEETH_BLUECHIP_VAULT_CREDIT_RATIO = 2e18;
    uint256 internal constant WEETH_BLUECHIP_VAULT_DEPOSIT_FEE = 0.01e18;
    uint256 internal constant WEETH_BLUECHIP_VAULT_REDEEM_FEE = 0.05e18;

    // Arbitrum Sepolia
    address internal constant WEETH_ARB_SEPOLIA_BLUECHIP_VAULT_ENGINE = address(0); // the address will be updated in
        // the mainnet
    address internal constant WEETH_ARB_SEPOLIA_BLUECHIP_VAULT_ASSET = address(0);
    address internal constant WEETH_ARB_SEPOLIA_BLUECHIP_VAULT_PRICE_ADAPTER = address(0);

    // Monad Testnet
    address internal constant WEETH_MONAD_TESTNET_BLUECHIP_VAULT_ENGINE = address(0); // the address will be updated
        // in the mainnet
    address internal constant WEETH_MONAD_TESTNET_BLUECHIP_VAULT_ASSET = address(0);
    address internal constant WEETH_MONAD_TESTNET_BLUECHIP_VAULT_PRICE_ADAPTER =
        address(0xa6a34AD9fe29902C53Ca3862667a1EA7E6ff6e13);
}
