// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract WEthCoreVault {
    uint128 internal constant WETH_CORE_VAULT_ID = 14;
    string internal constant WETH_CORE_VAULT_NAME = "WEth Core ZLP Vault";
    string internal constant WETH_CORE_VAULT_SYMBOL = "WEth-ZLP Core";
    uint128 internal constant WETH_CORE_VAULT_DEPOSIT_CAP = 1_000_000_000e18;
    uint128 internal constant WETH_CORE_VAULT_WITHDRAWAL_DELAY = 1 days;
    bool internal constant WETH_CORE_VAULT_IS_ENABLED = true;
    uint256 internal constant WETH_CORE_VAULT_CREDIT_RATIO = 1e18;
    uint256 internal constant WETH_CORE_VAULT_DEPOSIT_FEE = 0.01e18;
    uint256 internal constant WETH_CORE_VAULT_REDEEM_FEE = 0.05e18;

    // Arbitrum Sepolia
    address internal constant WETH_ARB_SEPOLIA_CORE_VAULT_ENGINE = address(0); // the address will be updated in the
        // mainnet
    address internal constant WETH_ARB_SEPOLIA_CORE_VAULT_ASSET = address(0);
    address internal constant WETH_ARB_SEPOLIA_CORE_VAULT_PRICE_ADAPTER = address(0);

    // Monad Testnet
    address internal constant WETH_MONAD_TESTNET_CORE_VAULT_ENGINE =
        address(0x6D90B34da7e2AdCB07FDf096242875ff7941eC74); // the address will be updated in the
        // mainnet
    address internal constant WETH_MONAD_TESTNET_CORE_VAULT_ASSET =
        address(0x03bEad4f3D886f0632b92F6f913358Feb765978E);
    address internal constant WETH_MONAD_TESTNET_CORE_VAULT_PRICE_ADAPTER =
        address(0x63BbF16F9813470ED12A8C2Bf1565235b7262D43);
}
