// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract WEthBluechipVault {
    uint128 internal constant WETH_BLUECHIP_VAULT_ID = 13;
    string internal constant WETH_BLUECHIP_VAULT_NAME = "WEth Bluechip ZLP Vault";
    string internal constant WETH_BLUECHIP_VAULT_SYMBOL = "WEth-ZLP Bluechip";
    uint128 internal constant WETH_BLUECHIP_VAULT_DEPOSIT_CAP = 1_000_000_000e18;
    uint128 internal constant WETH_BLUECHIP_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant WETH_BLUECHIP_VAULT_IS_ENABLED = true;
    uint256 internal constant WETH_BLUECHIP_VAULT_CREDIT_RATIO = 1e18;
    uint256 internal constant WETH_BLUECHIP_VAULT_DEPOSIT_FEE = 0.01e18;
    uint256 internal constant WETH_BLUECHIP_VAULT_REDEEM_FEE = 0.05e18;

    // Arbitrum Sepolia
    address internal constant WETH_ARB_SEPOLIA_BLUECHIP_VAULT_ENGINE = address(0); // the address will be updated in
        // the mainnet
    address internal constant WETH_ARB_SEPOLIA_BLUECHIP_VAULT_ASSET = address(0);
    address internal constant WETH_ARB_SEPOLIA_BLUECHIP_VAULT_PRICE_ADAPTER = address(0);

    // Monad Testnet
    address internal constant WETH_MONAD_TESTNET_BLUECHIP_VAULT_ENGINE =
        address(0x6D90B34da7e2AdCB07FDf096242875ff7941eC74); // the address will be updated in
        // the mainnet
    address internal constant WETH_MONAD_TESTNET_BLUECHIP_VAULT_ASSET =
        address(0x03bEad4f3D886f0632b92F6f913358Feb765978E);
    address internal constant WETH_MONAD_TESTNET_BLUECHIP_VAULT_PRICE_ADAPTER =
        address(0x63BbF16F9813470ED12A8C2Bf1565235b7262D43);
}
