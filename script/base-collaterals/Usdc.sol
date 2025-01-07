// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

// PRB Math dependencies
import { UD60x18, ud60x18 } from "@prb-math/UD60x18.sol";

abstract contract Usdc {
    /// @notice Collateral configuration parameters.
    string internal constant USDC_NAME = "USD Coin";
    string internal constant USDC_SYMBOL = "USDC";
    string internal constant USDC_PRICE_ADAPTER_NAME = "USDC/USD Zaros Price Adapter";
    string internal constant USDC_PRICE_ADAPTER_SYMBOL = "USDC/USD";
    uint256 internal constant MOCK_USDC_USD_PRICE = 1e6;
    address internal constant USDC_ADDRESS = address(0x95011b96c11A4cc96CD8351165645E00F68632a3);
    address internal constant USDC_PRICE_FEED = address(0x0153002d20B96532C639313c2d54c3dA09109309);
    uint8 internal constant USDC_DECIMALS = 6;
}
