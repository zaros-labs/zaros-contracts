// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract WstEth {
    /// @notice Market making engine collateral configuration parameters.
    uint256 internal constant WSTETH_MARKET_MAKING_ENGINE_COLLATERAL_ID = 4;
    uint120 internal constant WSTETH_MARKET_MAKING_ENGINE_CREDIT_RATIO = 1e18;
    bool internal constant WSTETH_MARKET_MAKING_ENGINE_IS_ENABLED = true;
    uint8 internal constant WSTETH_MARKET_MAKING_ENGINE_DECIMALS = 18;

    // Arbitrum Sepolia
    address internal constant WSTETH_ARB_SEPOLIA_MARKET_MAKING_ENGINE_ADDRESS = address(0x4);
    address internal constant WSTETH_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER = address(0x4);

    // Monad Testnet
    address internal constant WSTETH_MONAD_TESTNET_MARKET_MAKING_ENGINE_ADDRESS = address(0x4);
    address internal constant WSTETH_MONAD_TESTNET_MARKET_MAKING_ENGINE_PRICE_ADAPTER =
        address(0xE8f84e46ae7Cc30B7a23611Ef29C2FC1ed7618d1);
}
