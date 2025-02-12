// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract WBtcDegenVault {
    uint128 internal constant WBTC_DEGEN_VAULT_ID = 12;
    string internal constant WBTC_DEGEN_VAULT_NAME = "WBtc Degen ZLP Vault";
    string internal constant WBTC_DEGEN_VAULT_SYMBOL = "WBtc-ZLP Degen";
    uint128 internal constant WBTC_DEGEN_VAULT_DEPOSIT_CAP = 1_000_000_000e18;
    uint128 internal constant WBTC_DEGEN_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant WBTC_DEGEN_VAULT_IS_ENABLED = true;
    uint256 internal constant WBTC_DEGEN_VAULT_CREDIT_RATIO = 1e18;
    uint256 internal constant WBTC_DEGEN_VAULT_DEPOSIT_FEE = 0.01e18;
    uint256 internal constant WBTC_DEGEN_VAULT_REDEEM_FEE = 0.05e18;

    // Arbitrum Sepolia
    address internal constant WBTC_ARB_SEPOLIA_DEGEN_VAULT_ENGINE = address(0); // the address will be updated in the
        // mainnet
    address internal constant WBTC_ARB_SEPOLIA_DEGEN_VAULT_ASSET = address(0);
    address internal constant WBTC_ARB_SEPOLIA_DEGEN_VAULT_PRICE_ADAPTER = address(0);

    // Monad Testnet
    address internal constant WBTC_MONAD_TESTNET_DEGEN_VAULT_ENGINE =
        address(0x6D90B34da7e2AdCB07FDf096242875ff7941eC74); // the address will be updated in
        // the mainnet
    address internal constant WBTC_MONAD_TESTNET_DEGEN_VAULT_ASSET = address(0);
    address internal constant WBTC_MONAD_TESTNET_DEGEN_VAULT_PRICE_ADAPTER =
        address(0x33724F7A64fFC7393cC5472a4515F0057c878A0c);
}
