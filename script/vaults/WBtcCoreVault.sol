// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract WBtcCoreVault {
    uint128 internal constant WBTC_CORE_VAULT_ID = 11;
    string internal constant WBTC_CORE_VAULT_NAME = "WBtc Core ZLP Vault";
    string internal constant WBTC_CORE_VAULT_SYMBOL = "WBtc-ZLP Core";
    uint128 internal constant WBTC_CORE_VAULT_DEPOSIT_CAP = 2e18;
    uint128 internal constant WBTC_CORE_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant WBTC_CORE_VAULT_IS_ENABLED = true;
    uint256 internal constant WBTC_CORE_VAULT_CREDIT_RATIO = 2e18;
    uint256 internal constant WBTC_CORE_VAULT_DEPOSIT_FEE = 0.01e18;
    uint256 internal constant WBTC_CORE_VAULT_REDEEM_FEE = 0.05e18;

    // Arbitrum Sepolia
    address internal constant WBTC_ARB_SEPOLIA_CORE_VAULT_ENGINE = address(0); // the address will be updated in the
        // mainnet
    address internal constant WBTC_ARB_SEPOLIA_CORE_VAULT_ASSET = address(0);
    address internal constant WBTC_ARB_SEPOLIA_CORE_VAULT_PRICE_ADAPTER = address(0);

    // Monad Testnet
    address internal constant WBTC_MONAD_TESTNET_CORE_VAULT_ENGINE =
        address(0xd837cB495761D5bC5Bfa7d5dE876C0407E04Ae08); // the address will be updated in the
        // mainnet
    address internal constant WBTC_MONAD_TESTNET_CORE_VAULT_ASSET = address(0);
    address internal constant WBTC_MONAD_TESTNET_CORE_VAULT_PRICE_ADAPTER =
        address(0xC8e84af129FF5c5CB0bcE9a1972311feB4e392F9);
}
