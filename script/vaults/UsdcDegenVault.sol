// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract UsdcDegenVault {
    uint128 internal constant USDC_DEGEN_VAULT_ID = 9;
    string internal constant USDC_DEGEN_VAULT_NAME = "Usdc Degen ZLP Vault";
    string internal constant USDC_DEGEN_VAULT_SYMBOL = "Usdc-ZLP Degen";
    uint128 internal constant USDC_DEGEN_VAULT_DEPOSIT_CAP = 2e18;
    uint128 internal constant USDC_DEGEN_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant USDC_DEGEN_VAULT_IS_ENABLED = true;
    uint256 internal constant USDC_DEGEN_VAULT_CREDIT_RATIO = 2e18;
    uint256 internal constant USDC_DEGEN_VAULT_DEPOSIT_FEE = 0.01e18;
    uint256 internal constant USDC_DEGEN_VAULT_REDEEM_FEE = 0.05e18;

    // Arbitrum Sepolia
    address internal constant USDC_ARB_SEPOLIA_DEGEN_VAULT_ENGINE = address(0); // the address will be updated in the
        // mainnet
    address internal constant USDC_ARB_SEPOLIA_DEGEN_VAULT_ASSET = address(0);
    address internal constant USDC_ARB_SEPOLIA_DEGEN_VAULT_PRICE_ADAPTER = address(0);

    // Monad Testnet
    address internal constant USDC_MONAD_TESTNET_DEGEN_VAULT_ENGINE =
        address(0xd837cB495761D5bC5Bfa7d5dE876C0407E04Ae08); // the address will be updated in
        // the mainnet
    address internal constant USDC_MONAD_TESTNET_DEGEN_VAULT_ASSET =
        address(0x4470E455Aa0a43BA885B6F91bfC9FcEeDB9Dd083);
    address internal constant USDC_MONAD_TESTNET_DEGEN_VAULT_PRICE_ADAPTER =
        address(0x24c04E6Aa405EDB4e3847049dE459f8304145038);
}
