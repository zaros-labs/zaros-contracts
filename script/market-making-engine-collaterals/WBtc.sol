// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract WBtc {
    /// @notice Market making engine collateral configuration parameters.
    uint256 internal constant WBTC_MARKET_MAKING_ENGINE_COLLATERAL_ID = 3;
    uint120 internal constant WBTC_MARKET_MAKING_ENGINE_CREDIT_RATIO = 1e18;
    bool internal constant WBTC_MARKET_MAKING_ENGINE_IS_ENABLED = true;
    uint8 internal constant WBTC_MARKET_MAKING_ENGINE_DECIMALS = 8;

    // Arbitrum Sepolia
    address internal constant WBTC_ARB_SEPOLIA_MARKET_MAKING_ENGINE_ADDRESS = address(0x2);
    address internal constant WBTC_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER = address(0x2);

    // Monad Testnet
    address internal constant WBTC_MONAD_TESTNET_MARKET_MAKING_ENGINE_ADDRESS = address(0x2);
    address internal constant WBTC_MONAD_TESTNET_MARKET_MAKING_ENGINE_PRICE_ADAPTER =
        address(0xC8e84af129FF5c5CB0bcE9a1972311feB4e392F9);
}
