// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.25;

abstract contract Usdz {
    /// @notice Margin collateral configuration parameters.
    uint256 internal constant USDZ_MARGIN_COLLATERAL_ID = 2;
    uint128 internal constant USDZ_DEPOSIT_CAP = 50_000_000_000e18;
    uint120 internal constant USDZ_LOAN_TO_VALUE = 1e18;
    uint256 internal constant USDZ_MIN_DEPOSIT_MARGIN = 50e18;
    uint256 internal constant MOCK_USDZ_USD_PRICE = 1e6;
    address internal constant USDZ_ADDRESS = address(0x616076872dbF21DC5E2F2d8263AdbF1623495a11);
    address internal constant USDZ_PRICE_FEED = address(0xd9433D0E5b5Ae4593ba3880c25046BBC4dC4926C);
    uint256 internal constant USDZ_LIQUIDATION_PRIORITY = 2;
}
