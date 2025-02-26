// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract UsdToken {
    /// @notice Market making engine collateral configuration parameters.
    uint256 internal constant USD_TOKEN_MARKET_MAKING_ENGINE_COLLATERAL_ID = 5;
    uint120 internal constant USD_TOKEN_MARKET_MAKING_ENGINE_CREDIT_RATIO = 1e18;
    bool internal constant USD_TOKEN_MARKET_MAKING_ENGINE_IS_ENABLED = true;
    uint8 internal constant USD_TOKEN_MARKET_MAKING_ENGINE_DECIMALS = 18;

    // Arbitrum Sepolia
    address internal constant USD_TOKEN_ARB_SEPOLIA_MARKET_MAKING_ENGINE_ADDRESS = address(0x1);
    address internal constant USD_TOKEN_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER = address(0x1);

    // Monad Testnet
    address internal constant USD_TOKEN_MONAD_TESTNET_MARKET_MAKING_ENGINE_ADDRESS =
        address(0xbaDF69305038a4E009f79416340B7f4Bc5ea7a6b);
    address internal constant USD_TOKEN_MONAD_TESTNET_MARKET_MAKING_ENGINE_PRICE_ADAPTER =
        address(0xAC3624363e36d73526B06D33382cbFA9637318C3);
}
