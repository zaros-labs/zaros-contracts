// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract Usdz {
    /// @notice Margin collateral configuration parameters.
    uint256 internal constant USDZ_MARGIN_COLLATERAL_ID = 2;
    uint128 internal constant USDZ_DEPOSIT_CAP = 50_000_000_000e18;
    uint120 internal constant USDZ_LOAN_TO_VALUE = 1e18;
    uint256 internal constant USDZ_MIN_DEPOSIT_MARGIN = 50e18;
    uint256 internal constant MOCK_USDZ_USD_PRICE = 1e18;
    address internal constant USDZ_ADDRESS = address(0x64538B87a4C0554DFabf0A30943C351c8196858E);
    address internal constant USDZ_PRICE_FEED = address(0x0153002d20B96532C639313c2d54c3dA09109309);
    uint256 internal constant USDZ_LIQUIDATION_PRIORITY = 1;
    uint8 internal constant USDZ_DECIMALS = 18;
}
