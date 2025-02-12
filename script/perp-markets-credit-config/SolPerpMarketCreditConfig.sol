// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract SolPerpMarketCreditConfig {
    /// @notice SOL perp market credit configuration parameters.
    // TODO: Update the engine address when the market will be deployed.
    uint128 internal constant SOL_PERP_MARKET_CREDIT_CONFIG_ID = 7;
    uint128 internal constant SOL_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_START_THRESHOLD = 0.5e18;
    uint128 internal constant SOL_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_END_THRESHOLD = 0.6e18;
    uint128 internal constant SOL_PERP_MARKET_CREDIT_CONFIG_AUTO_DELEVERAGE_POWER_SCALE = 1e18;
    uint128 internal constant SOL_PERP_MARKET_CREDIT_CONFIG_MARKET_SHARE = 0.95e18;
    uint128 internal constant SOL_PERP_MARKET_CREDIT_CONFIG_FEE_RECIPIENTS_SHARE = 0.05e18;

    // Arbitrum Sepolia
    address internal constant SOL_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE = address(0x4);
    address internal constant SOL_ARB_SEPOLIA_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN = address(0x4);

    // Monad Testnet
    address internal constant SOL_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE =
        address(0x6D90B34da7e2AdCB07FDf096242875ff7941eC74);
    address internal constant SOL_MONAD_TESTNET_PERP_MARKET_CREDIT_CONFIG_ENGINE_USD_TOKEN =
        address(0xAC3624363e36d73526B06D33382cbFA9637318C3);
}
