// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract UsdcCoreVault {
    uint128 internal constant USDC_CORE_VAULT_ID = 8;
    string internal constant USDC_CORE_VAULT_NAME = "Usdc Core ZLP Vault";
    string internal constant USDC_CORE_VAULT_SYMBOL = "Usdc-ZLP Core";
    uint128 internal constant USDC_CORE_VAULT_DEPOSIT_CAP = 2e18;
    uint128 internal constant USDC_CORE_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant USDC_CORE_VAULT_IS_ENABLED = true;
    uint256 internal constant USDC_CORE_VAULT_CREDIT_RATIO = 2e18;
    uint256 internal constant USDC_CORE_VAULT_DEPOSIT_FEE = 0.01e18;
    uint256 internal constant USDC_CORE_VAULT_REDEEM_FEE = 0.05e18;

    // Arbitrum Sepolia
    address internal constant USDC_ARB_SEPOLIA_CORE_VAULT_ENGINE = address(0); // the address will be updated in the
        // mainnet
    address internal constant USDC_ARB_SEPOLIA_CORE_VAULT_ASSET = address(0);
    address internal constant USDC_ARB_SEPOLIA_CORE_VAULT_PRICE_ADAPTER = address(0);

    // Monad Testnet
    address internal constant USDC_MONAD_TESTNET_CORE_VAULT_ENGINE = address(0); // the address will be updated in the
        // mainnet
    address internal constant USDC_MONAD_TESTNET_CORE_VAULT_ASSET =
        address(0x4470E455Aa0a43BA885B6F91bfC9FcEeDB9Dd083);
    address internal constant USDC_MONAD_TESTNET_CORE_VAULT_PRICE_ADAPTER =
        address(0x24c04E6Aa405EDB4e3847049dE459f8304145038);
}
