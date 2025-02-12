// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract WEth {
    /// @notice Market making engine collateral configuration parameters.
    uint256 internal constant WETH_MARKET_MAKING_ENGINE_COLLATERAL_ID = 2;
    uint120 internal constant WETH_MARKET_MAKING_ENGINE_CREDIT_RATIO = 1e18;
    bool internal constant WETH_MARKET_MAKING_ENGINE_IS_ENABLED = true;
    uint8 internal constant WETH_MARKET_MAKING_ENGINE_DECIMALS = 18;

    // Arbitrum Sepolia
    address internal constant WETH_ARB_SEPOLIA_MARKET_MAKING_ENGINE_ADDRESS = address(0x3);
    address internal constant WETH_ARB_SEPOLIA_MARKET_MAKING_ENGINE_PRICE_ADAPTER = address(0x3);

    // Monad Testnet
    address internal constant WETH_MONAD_TESTNET_MARKET_MAKING_ENGINE_ADDRESS =
        address(0x03bEad4f3D886f0632b92F6f913358Feb765978E);
    address internal constant WETH_MONAD_TESTNET_MARKET_MAKING_ENGINE_PRICE_ADAPTER =
        address(0x63BbF16F9813470ED12A8C2Bf1565235b7262D43);
}
