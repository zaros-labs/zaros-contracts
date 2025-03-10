// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract WstEthCoreVault {
    uint128 internal constant WSTETH_CORE_VAULT_ID = 5;
    string internal constant WSTETH_CORE_VAULT_NAME = "WstEth Core ZLP Vault";
    string internal constant WSTETH_CORE_VAULT_SYMBOL = "WstEth-ZLP Core";
    uint128 internal constant WSTETH_CORE_VAULT_DEPOSIT_CAP = 1_000_000_000e18;
    uint128 internal constant WSTETH_CORE_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant WSTETH_CORE_VAULT_IS_ENABLED = true;
    uint256 internal constant WSTETH_CORE_VAULT_CREDIT_RATIO = 1e18;
    uint256 internal constant WSTETH_CORE_VAULT_DEPOSIT_FEE = 0.01e18;
    uint256 internal constant WSTETH_CORE_VAULT_REDEEM_FEE = 0.05e18;

    // Arbitrum Sepolia
    address internal constant WSTETH_ARB_SEPOLIA_CORE_VAULT_ENGINE = address(0); // the address will be updated in the
        // mainnet
    address internal constant WSTETH_ARB_SEPOLIA_CORE_VAULT_ASSET = address(0);
    address internal constant WSTETH_ARB_SEPOLIA_CORE_VAULT_PRICE_ADAPTER = address(0);

    // Monad Testnet
    address internal constant WSTETH_MONAD_TESTNET_CORE_VAULT_ENGINE =
        address(0x6D90B34da7e2AdCB07FDf096242875ff7941eC74); // the address will be updated in
        // the mainnet
    address internal constant WSTETH_MONAD_TESTNET_CORE_VAULT_ASSET = address(0);
    address internal constant WSTETH_MONAD_TESTNET_CORE_VAULT_PRICE_ADAPTER =
        address(0xE8f84e46ae7Cc30B7a23611Ef29C2FC1ed7618d1);
}
