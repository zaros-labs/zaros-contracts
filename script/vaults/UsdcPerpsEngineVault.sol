// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract UsdcPerpsEngineVault {
    uint128 internal constant USDC_PERPS_ENGINE_VAULT_ID = 16;
    string internal constant USDC_PERPS_ENGINE_VAULT_NAME = "USDC Perps Engine";
    string internal constant USDC_PERPS_ENGINE_VAULT_SYMBOL = "USDC-ZLP Perps Engine";
    uint128 internal constant USDC_PERPS_ENGINE_VAULT_DEPOSIT_CAP = 1_000_000_000e18;
    uint128 internal constant USDC_PERPS_ENGINE_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant USDC_PERPS_ENGINE_VAULT_IS_ENABLED = true;
    uint256 internal constant USDC_PERPS_ENGINE_VAULT_CREDIT_RATIO = 1e18;
    uint256 internal constant USDC_PERPS_ENGINE_VAULT_DEPOSIT_FEE = 0.01e18;
    uint256 internal constant USDC_PERPS_ENGINE_VAULT_REDEEM_FEE = 0.01e18;

    // Arbitrum Sepolia
    address internal constant USDC_ARB_SEPOLIA_PERPS_ENGINE_VAULT_ENGINE = address(0); // the address will be updated
        // in the mainnet
    address internal constant USDC_ARB_SEPOLIA_PERPS_ENGINE_VAULT_ASSET = address(0);
    address internal constant USDC_ARB_SEPOLIA_PERPS_ENGINE_VAULT_PRICE_ADAPTER = address(0);

    // Monad Testnet
    address internal constant USDC_MONAD_TESTNET_PERPS_ENGINE_VAULT_ENGINE =
        address(0x6D90B34da7e2AdCB07FDf096242875ff7941eC74); // the address will be
        // updated in the mainnet
    address internal constant USDC_MONAD_TESTNET_PERPS_ENGINE_VAULT_ASSET =
        address(0x3Bb8a17d8EDCAAbC0E064500367Efc89f90A6D83);
    address internal constant USDC_MONAD_TESTNET_PERPS_ENGINE_VAULT_PRICE_ADAPTER =
        address(0xD6AD9610075C4cC09f3048490E2aF40B9C43938d);
}
