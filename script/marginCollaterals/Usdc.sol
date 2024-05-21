// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract Usdc {
    /// @notice Margin collateral configuration parameters.
    uint256 internal constant USDC_MARGIN_COLLATERAL_ID = 1;
    uint128 internal constant USDC_DEPOSIT_CAP = 5_000_000_000e18;
    uint120 internal constant USDC_LOAN_TO_VALUE = 1e18;
    uint256 internal constant USDC_MIN_DEPOSIT_MARGIN = 50e18;
    uint256 internal constant MOCK_USDC_USD_PRICE = 1e6;
    address internal constant USDC_ADDRESS = address(0xC2D2a5FB0Dfb3473239C4147BdB6519159FBCE78);
    address internal constant USDC_PRICE_FEED = address(0xd9433D0E5b5Ae4593ba3880c25046BBC4dC4926C);
    uint256 internal constant USDC_LIQUIDATION_PRIORITY = 1;
}
