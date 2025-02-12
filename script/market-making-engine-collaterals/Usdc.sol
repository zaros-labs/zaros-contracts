// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract Usdc {
    /// @notice Market making engine collateral configuration parameters.
    uint256 internal constant USDC_MARKET_MAKING_ENGINE_COLLATERAL_ID = 1;
    uint120 internal constant USDC_MARKET_MAKING_ENGINE_CREDIT_RATIO = 1e18;
    bool internal constant USDC_MARKET_MAKING_ENGINE_IS_ENABLED = true;
    uint8 internal constant USDC_MARKET_MAKING_ENGINE_DECIMALS = 6;

    // Arbitrum Sepolia
    address internal constant USDC_ARB_SEPOLIA_MARKET_MAKING_ENGINE_ADDRESS = address(0x1);
    address internal constant USDC_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER = address(0x1);

    // Monad Testnet
    address internal constant USDC_MONAD_TESTNET_MARKET_MAKING_ENGINE_ADDRESS =
        address(0x4470E455Aa0a43BA885B6F91bfC9FcEeDB9Dd083);
    address internal constant USDC_MONAD_TESTNET_MARKET_MAKING_ENGINE_PRICE_ADAPTER =
        address(0x24c04E6Aa405EDB4e3847049dE459f8304145038);
}
