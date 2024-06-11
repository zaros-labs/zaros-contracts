// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract Usdc {
    /// @notice Margin collateral configuration parameters.
    uint256 internal constant USDC_MARGIN_COLLATERAL_ID = 2;
    uint128 internal constant USDC_DEPOSIT_CAP = 5_000_000_000e18;
    uint120 internal constant USDC_LOAN_TO_VALUE = 1e18;
    uint256 internal constant USDC_MIN_DEPOSIT_MARGIN = 50e18;
    uint256 internal constant MOCK_USDC_USD_PRICE = 1e6;
    address internal constant USDC_ADDRESS = address(0x788B06A2faDe5B7b61f9719bd4cF14DFF1426eF0);
    address internal constant USDC_PRICE_FEED = address(0x0153002d20B96532C639313c2d54c3dA09109309);
    uint256 internal constant USDC_LIQUIDATION_PRIORITY = 2;
    uint8 internal constant USDC_DECIMALS = 6;
    uint32 internal constant USDC_PRICE_FEED_HEARBEAT_SECONDS = 86_400;
}
